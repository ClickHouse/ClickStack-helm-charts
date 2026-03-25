import { test, expect } from '@playwright/test';

const TEST_EMAIL = 'smoke@test.local';
const TEST_PASSWORD = 'SmokeTest1234!';
const SEARCH_TERM = 'clickstack smoke test log';

test('register user and verify log appears on search page', async ({ page }) => {
  await page.goto('/register');

  await page.getByRole('textbox', { name: /email/i }).fill(TEST_EMAIL);
  await page.locator('input[name="password"]').fill(TEST_PASSWORD);
  await page.locator('input[name="confirmPassword"]').fill(TEST_PASSWORD);
  await page.getByRole('button', { name: 'Create' }).click();

  await page.waitForURL('**/search**', { timeout: 60_000 });

  const searchInput = page.getByTestId('search-input');
  await expect(searchInput).toBeVisible({ timeout: 30_000 });
  await searchInput.fill(SEARCH_TERM);
  await page.getByTestId('search-submit-button').click();
  await page.waitForLoadState('networkidle');

  const resultsTable = page.getByTestId('search-results-table');
  await expect(resultsTable).toBeVisible({ timeout: 30_000 });
  await expect(resultsTable).toContainText(SEARCH_TERM, { timeout: 30_000 });
});
