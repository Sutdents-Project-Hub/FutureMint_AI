import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

import { DemoAiProvider } from "../src/adapters/demoAiProvider";
import type {
  CaptureDraft,
  MoneyCategory,
  MoneyEventType,
} from "../src/contracts/models";

interface ExpectedDraft {
  type: MoneyEventType;
  amountMinor?: number;
  category: MoneyCategory;
  splitUserShareMinor?: number;
  missingAmount?: boolean;
  occurredDate?: string;
}

interface EvaluationCase {
  id: string;
  text: string;
  expectedDrafts: ExpectedDraft[];
  rejected?: boolean;
}

interface CaseResult {
  id: string;
  passed: boolean;
  schemaValid: boolean;
  checksPassed: number;
  checksTotal: number;
  failures: string[];
}

const fixturePath = resolve("test/fixtures/capture-evaluation.json");
const reportDirectory = resolve("reports");
const referenceTime = "2026-07-13T12:00:00+08:00";

const isSchemaValid = (draft: CaptureDraft): boolean =>
  draft.currency === "TWD" &&
  draft.needsConfirmation === true &&
  draft.source === "deterministic-demo" &&
  Number.isFinite(draft.confidence) &&
  draft.confidence >= 0 &&
  draft.confidence <= 1 &&
  Boolean(Date.parse(draft.occurredAt));

const evaluate = async (): Promise<void> => {
  const cases = JSON.parse(
    await readFile(fixturePath, "utf8"),
  ) as EvaluationCase[];
  const provider = new DemoAiProvider();
  const results: CaseResult[] = [];

  for (const fixture of cases) {
    const result = await provider.parseCapture({
      text: fixture.text,
      locale: "zh-TW",
      referenceTime,
    });
    const failures: string[] = [];
    let checksPassed = 0;
    let checksTotal = 1;
    const countMatches = result.drafts.length === fixture.expectedDrafts.length;
    if (countMatches) checksPassed += 1;
    else
      failures.push(
        `草稿數量預期 ${fixture.expectedDrafts.length}，實際 ${result.drafts.length}`,
      );

    checksTotal += 1;
    const rejectionMatches = fixture.rejected
      ? Boolean(result.rejectedReason) && result.drafts.length === 0
      : !result.rejectedReason;
    if (rejectionMatches) checksPassed += 1;
    else failures.push("拒絕分類不符合預期");

    for (const [index, expected] of fixture.expectedDrafts.entries()) {
      const actual = result.drafts[index];
      if (!actual) continue;
      const checks: Array<[string, boolean]> = [
        ["type", actual.type === expected.type],
        ["category", actual.category === expected.category],
        [
          "amountMinor",
          expected.missingAmount
            ? actual.amountMinor === undefined &&
              actual.missingFields.includes("amountMinor")
            : actual.amountMinor === expected.amountMinor,
        ],
        [
          "splitUserShareMinor",
          expected.splitUserShareMinor === undefined ||
            actual.split?.userShareMinor === expected.splitUserShareMinor,
        ],
        [
          "occurredDate",
          expected.occurredDate === undefined ||
            actual.occurredAt.startsWith(expected.occurredDate),
        ],
      ];
      for (const [name, passed] of checks) {
        checksTotal += 1;
        if (passed) checksPassed += 1;
        else failures.push(`draft ${index + 1} 的 ${name} 不符合預期`);
      }
    }

    const schemaValid =
      result.drafts.every(isSchemaValid) && result.drafts.length <= 5;
    checksTotal += 1;
    if (schemaValid) checksPassed += 1;
    else failures.push("輸出未通過安全 schema 檢查");
    results.push({
      id: fixture.id,
      passed: failures.length === 0,
      schemaValid,
      checksPassed,
      checksTotal,
      failures,
    });
  }

  const passedCases = results.filter((result) => result.passed).length;
  const schemaValidCases = results.filter(
    (result) => result.schemaValid,
  ).length;
  const checksPassed = results.reduce(
    (sum, result) => sum + result.checksPassed,
    0,
  );
  const checksTotal = results.reduce(
    (sum, result) => sum + result.checksTotal,
    0,
  );
  const summary = {
    generatedAt: new Date().toISOString(),
    provider: "deterministic-demo",
    syntheticCases: cases.length,
    passedCases,
    casePassRate: passedCases / cases.length,
    schemaValidCases,
    schemaValidityRate: schemaValidCases / cases.length,
    checksPassed,
    checksTotal,
    fieldAccuracyRate: checksPassed / checksTotal,
    results,
  };

  const percent = (value: number) => `${(value * 100).toFixed(1)}%`;
  const markdown = [
    "# Capture Evaluation Report",
    "",
    `- 合成案例：${summary.syntheticCases}`,
    `- 完整通過：${summary.passedCases}/${summary.syntheticCases}（${percent(summary.casePassRate)}）`,
    `- Schema 合法：${summary.schemaValidCases}/${summary.syntheticCases}（${percent(summary.schemaValidityRate)}）`,
    `- 欄位檢查：${summary.checksPassed}/${summary.checksTotal}（${percent(summary.fieldAccuracyRate)}）`,
    "- Provider：`deterministic-demo`（此報告不是 Azure OpenAI 成效證據）",
    "",
    "## 未通過案例",
    "",
    ...results
      .filter((result) => !result.passed)
      .flatMap((result) => [
        `### ${result.id}`,
        "",
        ...result.failures.map((failure) => `- ${failure}`),
        "",
      ]),
  ].join("\n");

  await mkdir(reportDirectory, { recursive: true });
  await writeFile(
    resolve(reportDirectory, "capture-evaluation.json"),
    `${JSON.stringify(summary, null, 2)}\n`,
    "utf8",
  );
  await writeFile(
    resolve(reportDirectory, "capture-evaluation.md"),
    `${markdown}\n`,
    "utf8",
  );
  process.stdout.write(`${markdown}\n`);
  if (passedCases !== cases.length) process.exitCode = 1;
};

void evaluate();
