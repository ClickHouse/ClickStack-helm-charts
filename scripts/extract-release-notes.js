// Extracts the changelog section for the current chart version from the root
// CHANGELOG.md (maintained by changesets) and writes it to
// charts/clickstack/RELEASE_NOTES.md, where chart-releaser picks it up as the
// GitHub release body (see .github/cr.yaml release-notes-file).
const fs = require("fs");
const path = require("path");
const yaml = require("js-yaml");

const repoRoot = path.join(__dirname, "..");
const chartDir = path.join(repoRoot, "charts", "clickstack");

const chart = yaml.load(
  fs.readFileSync(path.join(chartDir, "Chart.yaml"), "utf8")
);
const version = chart.version;

const changelog = fs.readFileSync(path.join(repoRoot, "CHANGELOG.md"), "utf8");

// Match the "## <version>" section up to the next "## " heading (or EOF).
const escaped = version.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const match = changelog.match(
  new RegExp(`^## ${escaped}\\n([\\s\\S]*?)(?=^## |(?![\\s\\S]))`, "m")
);

if (!match) {
  console.warn(
    `WARNING: no "## ${version}" section found in CHANGELOG.md; ` +
      "skipping RELEASE_NOTES.md generation (release will fall back to the chart description)."
  );
  process.exit(0);
}

const notes = match[1].trim() + "\n";
const outFile = path.join(chartDir, "RELEASE_NOTES.md");
fs.writeFileSync(outFile, notes);
console.log(`Wrote release notes for ${version} to ${outFile}`);
