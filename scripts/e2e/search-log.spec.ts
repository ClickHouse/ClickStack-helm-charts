import { test, expect } from '@playwright/test';

const TEST_EMAIL = 'smoke@test.local';
const TEST_PASSWORD = 'SmokeTest1234!';
const SEARCH_TERM = 'clickstack smoke test log';

async function registerOrLogin(page) {
  // /register redirects to /login once it learns a team exists, which races any visibility
  // check, so ask the endpoint the page uses before picking a form.
  const installation = await page.request.get('/api/installation');
  const { isTeamExisting } = await installation.json();

  if (!isTeamExisting) {
    await page.goto('/register');
    await page.getByRole('textbox', { name: /email/i }).fill(TEST_EMAIL);
    await page.locator('input[name="password"]').fill(TEST_PASSWORD);
    await page.locator('input[name="confirmPassword"]').fill(TEST_PASSWORD);
    await page.getByRole('button', { name: 'Create' }).click();
  } else {
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
