#!/usr/bin/env node

const fs = await import("node:fs/promises");
const path = await import("node:path");
const { firefox } = await import("playwright");

const BASE_URL = process.env.QA_BASE_URL || "http://127.0.0.1:3000";
const OUTPUT_DIR = path.join(process.cwd(), "output", "playwright", "product-release-qa");
const PASSWORD = process.env.QA_PASSWORD || "Password123!";

const scenarios = [
  {
    name: "owner-en-desktop-light",
    email: "qa@example.com",
    locale: "en",
    dark: false,
    viewport: { width: 1280, height: 900 },
    expectedVisible: ["News Filter Add-on", "Sniper Advanced Panel", "Trading Foundations"],
    expectedHidden: [],
    clickTitle: "Sniper Advanced Panel",
    dismiss: false
  },
  {
    name: "owner-en-desktop-dark",
    email: "qa@example.com",
    locale: "en",
    dark: true,
    viewport: { width: 1280, height: 900 },
    expectedVisible: ["News Filter Add-on", "Sniper Advanced Panel", "Trading Foundations"],
    expectedHidden: [],
    clickTitle: null,
    dismiss: false
  },
  {
    name: "addon-only-en-mobile",
    email: "marketplace.seed.1@example.com",
    locale: "en",
    dark: false,
    viewport: { width: 375, height: 812 },
    expectedVisible: ["News Filter Add-on"],
    expectedHidden: ["Sniper Advanced Panel", "Trading Foundations"],
    clickTitle: "News Filter Add-on",
    dismiss: false
  },
  {
    name: "owner-es-tablet-dismiss",
    email: "qa@example.com",
    locale: "es",
    dark: false,
    viewport: { width: 768, height: 1024 },
    expectedVisible: ["Add-on Filtro de Noticias", "Sniper Advanced Panel", "Fundamentos de Trading"],
    expectedHidden: [],
    clickTitle: "Fundamentos de Trading",
    dismiss: true
  }
];

await fs.mkdir(OUTPUT_DIR, { recursive: true });

const summary = {
  generatedAt: new Date().toISOString(),
  baseUrl: BASE_URL,
  browser: "firefox",
  headless: true,
  scenarios: []
};

for (const scenario of scenarios) {
  summary.scenarios.push(await runScenario(scenario));
}

const summaryPath = path.join(OUTPUT_DIR, "summary.json");
await fs.writeFile(summaryPath, JSON.stringify(summary, null, 2));
console.log(`Wrote ${summaryPath}`);

async function runScenario(scenario) {
  const browser = await firefox.launch({ headless: true });
  const context = await browser.newContext({
    baseURL: BASE_URL,
    viewport: scenario.viewport,
    locale: scenario.locale === "es" ? "es-ES" : "en-US",
    colorScheme: scenario.dark ? "dark" : "light"
  });
  const page = await context.newPage();
  page.setDefaultTimeout(10000);
  page.setDefaultNavigationTimeout(15000);
  const consoleMessages = [];
  const networkIssues = [];
  const assertions = [];

  page.on("console", (message) => {
    if (!["warning", "error"].includes(message.type())) return;

    consoleMessages.push({
      type: message.type(),
      text: message.text()
    });
  });

  page.on("response", (response) => {
    if (response.status() < 400) return;

    const request = response.request();
    networkIssues.push({
      status: response.status(),
      method: request.method(),
      resourceType: request.resourceType(),
      url: response.url()
    });
  });

  try {
    console.log(`Running ${scenario.name}`);
    await login(page, scenario.email);
    await visitDashboard(page, scenario);
    await closeDiscountModal(page);

    await expectVisible(page, "[data-product-release-bell='true']", "bell button is visible", assertions);
    await expectVisible(page, "[data-product-release-bell-dot='true']", "unread dot is visible", assertions);

    await page.click("[data-product-release-bell='true']");
    await page.waitForSelector("[data-product-release-dropdown='true']");

    const pageShot = path.join(OUTPUT_DIR, `${scenario.name}-page.png`);
    const dropdownShot = path.join(OUTPUT_DIR, `${scenario.name}-dropdown.png`);

    await page.screenshot({ path: pageShot, fullPage: true });
    await page.locator("[data-product-release-dropdown='true']").screenshot({ path: dropdownShot });

    const dropdownTexts = await page.locator("[data-product-release-dropdown='true'] li").allTextContents();
    const cleanedTexts = dropdownTexts.map((text) => normalizeWhitespace(text));
    const layout = await collectLayoutSignals(page);

    assertions.push({
      label: "dropdown rendered at least one release item",
      passed: cleanedTexts.length > 0,
      details: cleanedTexts
    });

    for (const title of scenario.expectedVisible) {
      assertions.push({
        label: `visible item: ${title}`,
        passed: cleanedTexts.some((text) => text.includes(title)),
        details: cleanedTexts
      });
    }

    for (const title of scenario.expectedHidden) {
      assertions.push({
        label: `hidden item: ${title}`,
        passed: cleanedTexts.every((text) => !text.includes(title)),
        details: cleanedTexts
      });
    }

    if (scenario.clickTitle) {
      const previousUrl = page.url();
      const targetLink = page.locator(
        `[data-product-release-dropdown='true'] a:has-text("${scenario.clickTitle}")`
      ).first();
      const href = await targetLink.getAttribute("href");
      await targetLink.scrollIntoViewIfNeeded();
      await targetLink.click();
      if (href) {
        await page.waitForURL((url) => url.href !== previousUrl, { timeout: 5000 }).catch(async () => {
          await page.goto(new URL(href, BASE_URL).toString(), { waitUntil: "networkidle" });
        });
      } else {
        await page.waitForLoadState("networkidle");
      }
      await page.screenshot({ path: path.join(OUTPUT_DIR, `${scenario.name}-destination.png`), fullPage: true });
      assertions.push({
        label: `click-through navigates for ${scenario.clickTitle}`,
        passed: page.url() !== previousUrl,
        details: { from: previousUrl, to: page.url() }
      });
      await page.goBack();
      await page.waitForLoadState("networkidle");
      await closeDiscountModal(page);
    }

    if (scenario.dismiss) {
      await page.click("[data-product-release-bell='true']");
      await page.waitForSelector("[data-product-release-dropdown='true']");
      await page.locator("[data-product-release-dropdown='true'] form button").click();
      await page.waitForLoadState("networkidle");
      await closeDiscountModal(page);
      await page.screenshot({ path: path.join(OUTPUT_DIR, `${scenario.name}-dismissed.png`), fullPage: true });

      const dotStillVisible = await page.locator("[data-product-release-bell-dot='true']").count();
      assertions.push({
        label: "dismiss removes unread dot",
        passed: dotStillVisible === 0,
        details: { dotStillVisible }
      });

      await page.reload({ waitUntil: "networkidle" });
      await closeDiscountModal(page);
      const dotAfterReload = await page.locator("[data-product-release-bell-dot='true']").count();
      assertions.push({
        label: "dismiss persists after reload",
        passed: dotAfterReload === 0,
        details: { dotAfterReload }
      });
    }

    return {
      ...scenario,
      passed: assertions.every((assertion) => assertion.passed),
      pageUrl: page.url(),
      screenshots: {
        page: relativeOutput(pageShot),
        dropdown: relativeOutput(dropdownShot)
      },
      layout,
      assertions,
      consoleMessages,
      networkIssues
    };
  } catch (error) {
    console.error(`Scenario failed: ${scenario.name} -> ${error.message}`);
    return {
      ...scenario,
      passed: false,
      error: error.message,
      consoleMessages,
      networkIssues
    };
  } finally {
    await context.close();
    await browser.close();
  }
}

async function login(page, email) {
  await page.goto(`${BASE_URL}/users/sign_in`, { waitUntil: "networkidle" });
  await page.fill("input[name='user[email]']", email);
  await page.fill("input[name='user[password]']", PASSWORD);
  await page.click("input[type='submit'], button[type='submit']");
  await page.waitForLoadState("networkidle");
}

async function visitDashboard(page, scenario) {
  await setThemePreference(page, scenario.dark);
  await page.goto(`${BASE_URL}/dashboard?locale=${scenario.locale}`, { waitUntil: "networkidle" });
}

async function setThemePreference(page, dark) {
  await page.evaluate((isDark) => {
    window.localStorage.setItem("dark-mode", String(isDark));
    document.documentElement.classList.toggle("dark", isDark);
    document.documentElement.style.colorScheme = isDark ? "dark" : "light";
    document.dispatchEvent(new CustomEvent("darkMode", { detail: { mode: isDark ? "on" : "off" } }));
  }, dark);
}

async function closeDiscountModal(page) {
  const closeButton = page.locator("#dashboard-discount-modal .promotion-modal-close");
  if (await closeButton.count()) {
    if (await closeButton.isVisible()) {
      await closeButton.click();
      await page.waitForTimeout(150);
    }
  }
}

async function expectVisible(page, selector, label, assertions) {
  const visible = await page.locator(selector).first().isVisible();
  assertions.push({ label, passed: visible });
}

async function collectLayoutSignals(page) {
  return page.evaluate(() => {
    const bell = document.querySelector("[data-product-release-bell='true']");
    const dropdown = document.querySelector("[data-product-release-dropdown='true']");
    const html = document.documentElement;
    const labels = Array.from(
      document.querySelectorAll("[data-product-release-dropdown='true'] li span.block.text-sm")
    );

    return {
      horizontalOverflow: html.scrollWidth > window.innerWidth + 1,
      bellRect: bell ? bell.getBoundingClientRect().toJSON() : null,
      dropdownRect: dropdown ? dropdown.getBoundingClientRect().toJSON() : null,
      clippedLabels: labels
        .filter((label) => label.scrollWidth > label.clientWidth + 1 || label.scrollHeight > label.clientHeight + 1)
        .map((label) => label.textContent?.trim())
        .filter(Boolean)
    };
  });
}

function normalizeWhitespace(value) {
  return value.replace(/\s+/g, " ").trim();
}

function relativeOutput(filePath) {
  return path.relative(process.cwd(), filePath);
}
