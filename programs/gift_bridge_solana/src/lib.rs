use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, MintTo, Burn};

declare_id!("Brdg111111111111111111111111111111111111111"); // MUST match Anchor.toml

#[program]
pub mod gift_bridge_solana {
    use super::*;

    /// Initialize bridge config (run once).
    pub fn initialize_config(
        ctx: Context<InitializeConfig>,
        gift_mint: Pubkey,
        polygon_bridge: [u8; 20],
    ) -> Result<()> {
        let cfg = &mut ctx.accounts.config;
        cfg.admin = ctx.accounts.admin.key();
        cfg.gift_mint = gift_mint;
        cfg.polygon_bridge = polygon_bridge;
        Ok(())
    }

    /// Allow the admin to add an additional authorized minter (e.g. backup multisig).
    pub fn add_minter(ctx: Context<UpdateMinters>, new_minter: Pubkey) -> Result<()> {
        let cfg = &mut ctx.accounts.config;
        require_keys_eq!(cfg.admin, ctx.accounts.admin.key(), BridgeError::UnauthorizedMinter);

        if !cfg.extra_minters.iter().any(|k| *k == new_minter) {
            cfg.extra_minters.push(new_minter);
        }
        Ok(())
    }

    /// Allow the admin to remove an authorized minter.
    pub fn remove_minter(ctx: Context<UpdateMinters>, minter: Pubkey) -> Result<()> {
        let cfg = &mut ctx.accounts.config;
        require_keys_eq!(cfg.admin, ctx.accounts.admin.key(), BridgeError::UnauthorizedMinter);

        cfg.extra_minters.retain(|k| *k != minter);
        Ok(())
    }

    /// Mint GIFT_SOL on Solana corresponding to a deposit on Polygon.
    /// Called by your off-chain relayer (admin or any authorized minter signer).
    pub fn mint_from_polygon(
        ctx: Context<MintFromPolygon>,
        amount: u64,
        deposit_id: [u8; 32],
    ) -> Result<()> {
        require!(amount > 0, BridgeError::ZeroAmount);

        // Only admin or explicitly authorized minters may mint from Polygon deposits.
        let cfg = &ctx.accounts.config;
        let caller = ctx.accounts.admin.key();
        let is_admin = cfg.admin == caller;
        let is_extra = cfg.extra_minters.iter().any(|k| *k == caller);
        require!(is_admin || is_extra, BridgeError::UnauthorizedMinter);

        // Prevent replay
        let processed = &mut ctx.accounts.processed_deposit;
        require!(!processed.used, BridgeError::DepositAlreadyProcessed);
        processed.used = true;
        processed.deposit_id = deposit_id;

        // Mint tokens to recipient using mint authority PDA
        let cfg_key = cfg.key();

        let bump = ctx.bumps.mint_authority;
        let seeds: &[&[u8]] = &[
            b"mint_authority",
            cfg_key.as_ref(),
            &[bump],
        ];
        let signer_seeds = &[&seeds[..]];

        let cpi_accounts = MintTo {
            mint: ctx.accounts.gift_mint.to_account_info(),
            to: ctx.accounts.recipient_token_account.to_account_info(),
            authority: ctx.accounts.mint_authority.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer_seeds,
        );

        token::mint_to(cpi_ctx, amount)?;

        Ok(())
    }

    /// Burn GIFT_SOL on Solana to request withdrawal on Polygon.
    /// Anyone can call this for themselves.
    pub fn burn_for_polygon(
        ctx: Context<BurnForPolygon>,
        amount: u64,
        polygon_recipient: [u8; 20],
    ) -> Result<()> {
        require!(amount > 0, BridgeError::ZeroAmount);

        // Burn from user’s token account
        let cpi_accounts = Burn {
            mint: ctx.accounts.gift_mint.to_account_info(),
            from: ctx.accounts.user_token_account.to_account_info(),
            authority: ctx.accounts.user.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
        );
        token::burn(cpi_ctx, amount)?;

        // Emit event for off-chain relayer
        emit!(BurnForPolygonEvent {
            user: ctx.accounts.user.key(),
            amount,
            polygon_recipient,
        });

        Ok(())
    }
}

#[account]
pub struct Config {
    pub admin: Pubkey,
    pub gift_mint: Pubkey,
    pub polygon_bridge: [u8; 20],
    /// Additional authorized minters (backup multisigs, etc.)
    pub extra_minters: Vec<Pubkey>,
}

#[account]
pub struct ProcessedDeposit {
    pub used: bool,
    pub deposit_id: [u8; 32],
}

#[derive(Accounts)]
pub struct InitializeConfig<'info> {
    #[account(
        init,
        payer = admin,
        seeds = [b"config"],
        bump,
        // Discriminator + admin + gift_mint + polygon_bridge + extra_minters Vec<Pubkey> (up to 16)
        space = 8  // discriminator
              + 32 // admin
              + 32 // gift_mint
              + 20 // polygon_bridge
              + 4  // Vec length prefix
              + 16 * 32 // up to 16 extra minters
    )]
    pub config: Account<'info, Config>,

    #[account(mut)]
    pub admin: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(amount: u64, deposit_id: [u8; 32])]
pub struct MintFromPolygon<'info> {
    #[account(mut)]
    pub config: Account<'info, Config>,

    #[account(
        mut,
        constraint = gift_mint.key() == config.gift_mint
    )]
    pub gift_mint: Account<'info, Mint>,

    /// CHECK: PDA acting as mint authority
    #[account(
        seeds = [b"mint_authority", config.key().as_ref()],
        bump
    )]
    pub mint_authority: UncheckedAccount<'info>,

    #[account(
        mut,
        constraint = recipient_token_account.mint == gift_mint.key()
    )]
    pub recipient_token_account: Account<'info, TokenAccount>,

        #[account(
        init,
        payer = admin,
        seeds = [b"processed_deposit", deposit_id.as_ref()],
        bump,
        space = 8 + 1 + 32
    )]
    pub processed_deposit: Account<'info, ProcessedDeposit>,

    #[account(mut)]
    pub admin: Signer<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct BurnForPolygon<'info> {
    #[account(
        has_one = gift_mint
    )]
    pub config: Account<'info, Config>,

    #[account(
        mut,
        constraint = gift_mint.key() == config.gift_mint
    )]
    pub gift_mint: Account<'info, Mint>,

    #[account(
        mut,
        constraint = user_token_account.mint == gift_mint.key(),
        constraint = user_token_account.owner == user.key(),
    )]
    pub user_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub user: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct UpdateMinters<'info> {
    #[account(mut)]
    pub config: Account<'info, Config>,

    #[account(mut)]
    pub admin: Signer<'info>,
}

#[event]
pub struct BurnForPolygonEvent {
    pub user: Pubkey,
    pub amount: u64,
    pub polygon_recipient: [u8; 20],
}

#[error_code]
pub enum BridgeError {
    #[msg("Amount is zero")]
    ZeroAmount,
    #[msg("Deposit already processed")]
    DepositAlreadyProcessed,
    #[msg("Caller is not an authorized minter")]
    UnauthorizedMinter,
}
