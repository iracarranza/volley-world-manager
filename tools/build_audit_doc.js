// Builds the prose-audit review document from docs/review/prose_audit_findings.json.
//
//   node tools/build_audit_doc.js
//
// Regenerating is cheap and idempotent, which is why the findings are committed
// as data and the document is not: the JSON is the expensive artefact.

const fs = require('fs')
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  BorderStyle, ShadingType, PageBreak,
} = require('docx')

const findings = JSON.parse(
  fs.readFileSync('docs/review/prose_audit_findings.json', 'utf8')
)

const KIND_LABEL = {
  'tells-not-shows': 'TELLS, DOES NOT SHOW',
  'redundant': 'REDUNDANT',
  'meta-commentary': 'META-COMMENTARY',
  'overlong-narrative': 'OVERLONG NARRATIVE',
  'vibe-code': 'VIBE CODE',
  'monkey-code': 'MONKEY CODE',
}

const INK = '1A1A1A'
const QUIET = '5A5A5A'
const FLAG = '8A2B20'

const body = (text, opts = {}) => new Paragraph({
  spacing: { after: opts.after === undefined ? 100 : opts.after, line: 276 },
  indent: opts.indent || undefined,
  children: [new TextRun({
    text, font: 'Calibri', size: opts.size || 21,
    color: opts.color || INK, bold: !!opts.bold, italics: !!opts.italics,
  })],
})

const label = (runs) => new Paragraph({
  spacing: { before: 240, after: 60 },
  children: runs,
})

// Quoted source keeps its own line breaks, so each source line is its own
// paragraph -- docx has no newline inside a run.
const quoteLines = (quote) => quote.split('\n').map((line, index) => new Paragraph({
  spacing: { after: 0, line: 240 },
  indent: { left: 420 },
  shading: { type: ShadingType.CLEAR, fill: 'F2F0EB' },
  border: {
    left: { style: BorderStyle.SINGLE, size: 12, color: 'C4BDB0', space: 8 },
  },
  children: [new TextRun({
    text: line.length ? line : ' ',
    font: 'Consolas', size: 18, color: '2B2B2B',
  })],
}))

const decision = () => new Paragraph({
  spacing: { before: 120, after: 320 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: 'D8D2C6', space: 10 } },
  children: [
    new TextRun({ text: 'YOUR CALL:  ', font: 'Calibri', size: 20, bold: true, color: QUIET }),
    new TextRun({ text: 'keep  /  cut  /  rewrite  — ', font: 'Calibri', size: 20, color: QUIET }),
    new TextRun({ text: ' '.repeat(40), font: 'Calibri', size: 20, color: 'BBBBBB' }),
  ],
})

const children = []

children.push(new Paragraph({
  spacing: { after: 80 },
  children: [new TextRun({
    text: 'Comment and code audit', font: 'Calibri Light', size: 52, color: INK,
  })],
}))
children.push(new Paragraph({
  spacing: { after: 320 },
  children: [new TextRun({
    text: 'Volley World Manager · flagged explanation text and vibe-coded patterns',
    font: 'Calibri', size: 24, color: QUIET,
  })],
}))

body('How to use this', { bold: true, after: 60 })
children.push(children.pop())
children.push(new Paragraph({
  spacing: { before: 120, after: 60 },
  children: [new TextRun({ text: 'How to use this', font: 'Calibri', size: 24, bold: true, color: INK })],
}))
children.push(body(
  'Every entry below quotes text verbatim from the file and line named. Nothing has been changed in the '
  + 'codebase. Mark each one on its YOUR CALL line — keep, cut, or rewrite — add any note you like, '
  + 'and send the file back; the edits will be applied from your marks.'
))
children.push(body(
  'What the flag means: the house rule is that a comment says why, not what, and that a recorded defect '
  + 'carries the measurement that found it. A passage is flagged when it restates the code, asserts '
  + 'significance instead of giving the fact, tells a bug story with no number in it, or talks about the '
  + 'process rather than the decision.'
))

children.push(new Paragraph({
  spacing: { before: 200, after: 60 },
  children: [new TextRun({ text: 'What has and has not been checked', font: 'Calibri', size: 24, bold: true, color: INK })],
}))
children.push(body(
  'The citations are reliable. Every quote was located mechanically in its file: 127 of 128 matched '
  + 'verbatim at the exact line claimed, and the one exception is a quote that begins mid-line rather '
  + 'than a bad citation.'
))
children.push(body(
  'The judgement is not corroborated. Each flag is one reader’s opinion. A second, '
  + 'reject-by-default pass was meant to challenge every one of them and was cut short before it ran, so '
  + 'expect some of these to be wrong — particularly where a comment records a real defect and does '
  + 'give its number, which is house style and should stay.'
))
children.push(body(
  'The coverage is partial. Six of twenty-one planned readers finished. This document covers '
  + 'rally_simulator.gd in full and player_actor_3d.gd in full. It does NOT yet cover worksheet.gd, '
  + 'tactical_court.gd, main.gd, journal_screen.gd, desk_screen.gd, cogniticon_marks.gd, ink_outline.gd, '
  + 'player_generator.gd, geometric_attack_resolver.gd, cognition_compiler.gd, ui_style_system.gd, '
  + 'rally_feature_flags.gd, shadow_reception_system.gd, rally_calibration_report.gd or '
  + 'shadow_block_system.gd.'
))

const byFile = {}
for (const f of findings) (byFile[f.file] = byFile[f.file] || []).push(f)

const counts = {}
for (const f of findings) counts[f.kind] = (counts[f.kind] || 0) + 1
children.push(new Paragraph({
  spacing: { before: 200, after: 60 },
  children: [new TextRun({ text: 'What was flagged', font: 'Calibri', size: 24, bold: true, color: INK })],
}))
for (const [kind, n] of Object.entries(counts).sort((a, b) => b[1] - a[1])) {
  children.push(new Paragraph({
    spacing: { after: 40 }, indent: { left: 280 },
    children: [
      new TextRun({ text: String(n).padStart(3, ' ') + '   ', font: 'Consolas', size: 20, color: FLAG }),
      new TextRun({ text: KIND_LABEL[kind] || kind, font: 'Calibri', size: 21, color: INK }),
    ],
  }))
}

let index = 0
for (const file of Object.keys(byFile).sort()) {
  children.push(new Paragraph({ children: [new PageBreak()] }))
  children.push(new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { after: 40 },
    children: [new TextRun({ text: file, font: 'Consolas', size: 28, bold: true, color: INK })],
  }))
  children.push(body(`${byFile[file].length} flagged passages`, { color: QUIET, italics: true, after: 240 }))

  for (const f of byFile[file].sort((a, b) => (a._actual_line || a.line) - (b._actual_line || b.line))) {
    index += 1
    const line = f._actual_line || f.line
    children.push(label([
      new TextRun({ text: `${index}.  `, font: 'Calibri', size: 22, bold: true, color: INK }),
      new TextRun({ text: `line ${line}`, font: 'Consolas', size: 20, color: INK }),
      new TextRun({ text: '   ·   ', font: 'Calibri', size: 20, color: 'AAAAAA' }),
      new TextRun({
        text: KIND_LABEL[f.kind] || f.kind, font: 'Calibri', size: 19, bold: true, color: FLAG,
      }),
      new TextRun({ text: `   ·   ${f.severity}`, font: 'Calibri', size: 19, color: QUIET }),
    ]))
    for (const p of quoteLines(f.quote)) children.push(p)
    children.push(new Paragraph({
      spacing: { before: 140, after: 60 },
      indent: { left: 420 },
      children: [
        new TextRun({ text: 'Why flagged.  ', font: 'Calibri', size: 20, bold: true, color: INK }),
        new TextRun({ text: f.why, font: 'Calibri', size: 20, color: INK }),
      ],
    }))
    children.push(new Paragraph({
      spacing: { after: 60 },
      indent: { left: 420 },
      children: [
        new TextRun({ text: 'Suggested.  ', font: 'Calibri', size: 20, bold: true, color: QUIET }),
        new TextRun({ text: f.suggestion, font: 'Calibri', size: 20, color: QUIET }),
      ],
    }))
    children.push(decision())
  }
}

const doc = new Document({
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1080, bottom: 1080, left: 1080, right: 1080 } } },
    children,
  }],
})

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync('docs/review/comment_audit.docx', buf)
  console.log('wrote docs/review/comment_audit.docx', buf.length, 'bytes,', index, 'entries')
})
