import { test, expect } from '@playwright/test';

const TEST_EMAIL = 'smoke@test.local';
const TEST_PASSWORD = 'SmokeTest1234!';
const SEARCH_TERM = 'clickstack smoke test log';

async function registerOrLogin(page) {
  await page.goto('/register');

  // If the user already exists (e.g. from a previous attempt), the
  // confirmPassword field won't be present. Fall back to login.
  const confirmPassword = page.locator('input[name="confirmPassword"]');
  const isRegisterPage = await confirmPassword.isVisible({ timeout: 5_000 }).catch(() => false);

  if (isRegisterPage) {
    await page.getByRole('textbox', { name: /email/i }).fill(TEST_EMAIL);
    await page.locator('input[name="password"]').fill(TEST_PASSWORD);
    await confirmPassword.fill(TEST_PASSWORD);
    await page.getByRole('button', { name: 'Create' }).click();
  } else {
    // Registration not available — try logging in instead
    await page.goto('/login');
    await page.getByRole('textbox', { name: /email/i }).fill(TEST_EMAIL);
    await page.locator('input[name="password"]').fill(TEST_PASSWORD);
    await page.getByRole('button', { name: /log in|sign in/i }).click();
  }

  await page.waitForURL('**/search**', { timeout: 60_000 });
}

test('register user and verify log appears on search page', async ({ page }) => {
  await registerOrLogin(page);

  const searchInput = page.getByTestId('search-input');
  await expect(searchInput).toBeVisible({ timeout: 30_000 });
  await searchInput.fill(SEARCH_TERM);

  // Dismiss the autocomplete suggestions overlay before clicking submit,
  // otherwise the dropdown portal intercepts pointer events.
  await page.keyboard.press('Escape');

  await page.getByTestId('search-submit-button').click();
  await page.waitForLoadState('networkidle');

  const resultsTable = page.getByTestId('search-results-table');
  await expect(resultsTable).toBeVisible({ timeout: 30_000 });
  await expect(resultsTable).toContainText(SEARCH_TERM, { timeout: 30_000 });
});
