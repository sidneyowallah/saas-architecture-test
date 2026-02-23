module.exports = {
  // Inherit the standard rules (feat, fix, chore, docs, etc.)
  extends: ['@commitlint/config-conventional'],

  rules: {
    // 1. Force the developer to include a scope: feat(SCOPE): message
    'scope-empty': [2, 'never'],

    // 2. Disable the default rule that forces scopes to be lowercase
    // (Because we want uppercase Jira tickets like CYBER-123)
    'scope-case': [0],

    // 3. Enable our custom Jira ticket rule
    'jira-ticket-format': [2, 'always'],
  },

  plugins: [
    {
      rules: {
        'jira-ticket-format': (parsed) => {
          const { scope } = parsed;

          // Regex for a Jira Ticket: 2-10 Uppercase letters, a hyphen, and numbers
          // Example: PROJ-123, CYBER-404
          const jiraRegex = /^[A-Z]{2,10}-\d+$/;

          if (!scope || !jiraRegex.test(scope)) {
            return [
              false,
              `The commit scope must be a valid Jira ticket (e.g., PROJ-123).\n\n  ✅ Correct: feat(PROJ-123): add new dashboard\n  ❌ Incorrect: ${parsed.type}(${scope}): ${parsed.subject}`,
            ];
          }
          return [true];
        },
      },
    },
  ],
};
