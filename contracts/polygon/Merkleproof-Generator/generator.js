// Minimal, dependency-light merkle builder using ethers v6
(() => {
  const { ethers } = window;
  if (!ethers) { alert("ethers not loaded"); return; }

  const TYPEHASH = ethers.keccak256(ethers.toUtf8Bytes(
    "GiftMintLeafV1(address registry,uint256 batchId,uint256 reserveId,uint256 quantity,uint256 fineWeightMg,bytes32 serialHash,bytes32 mineHash,bytes32 barStandardHash,bytes32 docHash,uint256 mintedAtISO,uint256 presenceMask)"
  ));
  const UNKNOWN = ethers.keccak256(ethers.toUtf8Bytes("UNKNOWN"));

  const enc = ethers.AbiCoder.defaultAbiCoder();

  function hashStrOrUnknown(s, presentBit, bits) {
    const present = s && String(s).trim().length > 0;
    const v = present ? ethers.keccak256(ethers.toUtf8Bytes(String(s).trim())) : UNKNOWN;
    const newBits = present ? (bits | (1n << BigInt(presentBit))) : bits;
    return { h: v, bits: newBits };
  }

  function leafHash(registry, batchId, row) {
    // presence bit layout:
    // bit0: serialHash, bit1: mineHash, bit2: barStandardHash, bit3: docHash, bit4: mintedAtISO
    let presence = 0n;

    const serial = hashStrOrUnknown(row.serial, 0, presence); presence = serial.bits;
    const mine   = hashStrOrUnknown(row.mine,   1, presence); presence = mine.bits;
    const std    = hashStrOrUnknown(row.barStandard, 2, presence); presence = std.bits;
    const doc    = hashStrOrUnknown(row.doc,    3, presence); presence = doc.bits;

    const ts = row.mintedAtISO && String(row.mintedAtISO).trim().length > 0 ? BigInt(row.mintedAtISO) : 0n;
    if (ts > 0n) presence = presence | (1n << 4n);

    const types = [
      "bytes32","address","uint256","uint256","uint256","uint256",
      "bytes32","bytes32","bytes32","bytes32","uint256","uint256"
    ];
    const values = [
      TYPEHASH,
      registry,
      BigInt(batchId),
      BigInt(row.reserveId),
      BigInt(row.quantity),
      BigInt(row.fineWeightMg),
      serial.h,
      mine.h,
      std.h,
      doc.h,
      ts,
      presence
    ];
    const packed = enc.encode(types, values);
    return ethers.keccak256(packed);
  }

  function toBytes(hex) { return ethers.getBytes(hex); }

  function buildTree(leafHexes) {
    // Build levels with sorted pair hashing (same as OZ MerkleProof)
    const levels = [];
    levels.push(leafHexes.slice());

    while (levels[levels.length - 1].length > 1) {
      const prev = levels[levels.length - 1];
      const next = [];
      for (let i = 0; i < prev.length; i += 2) {
        const a = prev[i];
        const b = (i + 1 < prev.length) ? prev[i + 1] : prev[i];
        // sort pair
        const [x, y] = (a.toLowerCase() < b.toLowerCase()) ? [a, b] : [b, a];
        const combined = ethers.concat([toBytes(x), toBytes(y)]);
        next.push(ethers.keccak256(combined));
      }
      levels.push(next);
    }
    return levels;
  }

  function rootOf(levels) {
    const top = levels[levels.length - 1];
    return top.length ? top[0] : ethers.ZeroHash;
  }

  function proofFor(index, levels) {
    const proof = [];
    let idx = index;
    for (let level = 0; level < levels.length - 1; level++) {
      const arr = levels[level];
      const isRight = (idx % 2) === 1;
      const pairIdx = isRight ? idx - 1 : idx + 1;
      if (pairIdx < arr.length) {
        proof.push(arr[pairIdx]);
      } else {
        // no sibling => duplicate
        proof.push(arr[idx]);
      }
      idx = Math.floor(idx / 2);
    }
    return proof;
  }

  function parseCSV(text) {
    const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
    if (lines.length === 0) return [];
    const header = lines[0].split(",").map(s => s.trim());
    const idx = Object.fromEntries(header.map((h, i) => [h, i]));
    const req = ["reserveId","quantity","fineWeightMg","serial","mine","barStandard","doc","mintedAtISO"];
    for (const k of req) if (!(k in idx)) throw new Error(`Missing column: ${k}`);

    const rows = [];
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(",").map(s => s.trim());
      if (!cols.length || cols.join("") === "") continue;
      rows.push({
        reserveId: cols[idx.reserveId],
        quantity: cols[idx.quantity],
        fineWeightMg: cols[idx.fineWeightMg],
        serial: cols[idx.serial],
        mine: cols[idx.mine],
        barStandard: cols[idx.barStandard],
        doc: cols[idx.doc],
        mintedAtISO: cols[idx.mintedAtISO]
      });
    }
    return rows;
  }

  function sumQuantities(rows) {
    return rows.reduce((acc, r) => (acc + BigInt(r.quantity || 0)), 0n);
  }

  const state = {
    dataset: [],
    leaves: [],
    proofs: {},
    root: ethers.ZeroHash,
    schemaHash: ethers.ZeroHash
  };

  async function build() {
    const registry = document.getElementById("registry").value.trim();
    const batchId  = document.getElementById("batchId").value.trim();
    if (!ethers.isAddress(registry)) { alert("Invalid registry address"); return; }
    if (!batchId) { alert("Batch ID required"); return; }

    const csv = document.getElementById("csv").value;
    const rows = parseCSV(csv);
    if (rows.length === 0) { alert("No rows"); return; }

    const leaves = rows.map(r => leafHash(registry, batchId, r));
    const levels = buildTree(leaves);
    const root = rootOf(levels);

    // proofs map (leafHash => bytes32[])
    const proofs = {};
    for (let i = 0; i < leaves.length; i++) {
      proofs[leaves[i]] = proofFor(i, levels);
    }

    // dataset JSON with exact scalar/hash values needed for Remix
    const dataset = rows.map((r, i) => ({
      index: i,
      reserveId: r.reserveId,
      quantity: r.quantity,
      fineWeightMg: r.fineWeightMg,
      // presence mask re-derived the same way
      serialHash: (r.serial && r.serial.trim()) ? ethers.keccak256(ethers.toUtf8Bytes(r.serial.trim())) : UNKNOWN,
      mineHash:   (r.mine   && r.mine.trim())   ? ethers.keccak256(ethers.toUtf8Bytes(r.mine.trim()))   : UNKNOWN,
      barStandardHash: (r.barStandard && r.barStandard.trim()) ? ethers.keccak256(ethers.toUtf8Bytes(r.barStandard.trim())) : UNKNOWN,
      docHash:    (r.doc    && r.doc.trim())    ? ethers.keccak256(ethers.toUtf8Bytes(r.doc.trim()))    : UNKNOWN,
      mintedAtISO: (r.mintedAtISO && String(r.mintedAtISO).trim().length>0) ? r.mintedAtISO : "0",
      presenceMask: String(
        ((r.serial && r.serial.trim())     ? (1n<<0n) : 0n) |
        ((r.mine && r.mine.trim())         ? (1n<<1n) : 0n) |
        ((r.barStandard && r.barStandard.trim()) ? (1n<<2n) : 0n) |
        ((r.doc && r.doc.trim())           ? (1n<<3n) : 0n) |
        ((r.mintedAtISO && String(r.mintedAtISO).trim().length>0) ? (1n<<4n) : 0n)
      ),
      leafHash: leaves[i],
      proof: proofs[leaves[i]]
    }));

    // schema hash (optional convenience)
    const hint = document.getElementById("schemaHint").value.trim();
    const schemaHash = hint ? ethers.keccak256(ethers.toUtf8Bytes(hint)) : ethers.ZeroHash;

    state.dataset = dataset;
    state.leaves  = leaves;
    state.proofs  = proofs;
    state.root    = root;
    state.schemaHash = schemaHash;

    document.getElementById("root").value = root;
    document.getElementById("schemaHash").value = schemaHash;

    const cap = sumQuantities(rows);
    console.log("cap (sum quantity):", cap.toString());
    alert("Built! Root ready. cap (sum quantity) = " + cap.toString());
  }

  function download(name, json) {
    const blob = new Blob([JSON.stringify(json, null, 2)], {type:"application/json"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  function downloadDataset() {
    if (!state.dataset.length) { alert("Build first"); return; }
    download("dataset.json", state.dataset);
  }

  function downloadProofs() {
    if (!state.dataset.length) { alert("Build first"); return; }
    download("proofs.json", state.proofs);
  }

  function downloadRoot() {
    if (!state.dataset.length) { alert("Build first"); return; }
    const blob = new Blob([state.root], {type:"text/plain"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "root.txt";
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  window.Merkle = { build, downloadDataset, downloadProofs, downloadRoot };
})();
