const fs = require("fs");
const yaml = require("js-yaml");
const { version } = require("../package.json");

// Update Chart.yaml files with the new version
const charts = ["./charts/hdx-oss-v2"];

charts.forEach((chartPath) => {
  const chartFile = `${chartPath}/Chart.yaml`;
  const chart = yaml.load(fs.readFileSync(chartFile, "utf8"));
  chart.version = version;
  fs.writeFileSync(chartFile, yaml.dump(chart));
});
