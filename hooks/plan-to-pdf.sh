#!/bin/bash
# Hook: PostToolUse(Write) - auto-generate PDF when a plan .md is written to plans/
# (also routines/ specs; _template.md excluded)

FILE_PATH=$(jq -r '.tool_input.file_path' < /dev/stdin)

# Only process .md files in the plans/ directory (skip .gitkeep etc.)
if [[ "$FILE_PATH" == */plans/*.md || ( "$FILE_PATH" == */routines/*.md && "$FILE_PATH" != */_template.md ) ]]; then
  PDF_PATH="${FILE_PATH%.md}.pdf"

  # Use md-to-pdf (bundled Chromium, no LaTeX needed)
  # md-to-pdf outputs .pdf in the same directory as the input file by default
  if npx --yes md-to-pdf "$FILE_PATH" 2>/dev/null; then
    echo "PDF generated: ${FILE_PATH%.md}.pdf"
  else
    echo "Warning: PDF generation failed for $FILE_PATH" >&2
  fi
fi

exit 0
