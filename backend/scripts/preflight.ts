import "dotenv/config";
import { validateStartupConfig, summarizeStartupError } from "../src/config/startupConfig";
try {
  validateStartupConfig();
  console.info("futuremint_configuration_valid", { phase: "configuration" });
} catch (error) {
  console.error("futuremint_configuration_invalid", summarizeStartupError(error));
  process.exitCode = 1;
}
