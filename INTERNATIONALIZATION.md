# Internationalization (i18n) Documentation

This document describes the internationalization setup for the Taschengeld App using Paraglide JS 2.0.

## Overview

The app supports multiple languages through Paraglide JS 2.0, a modern i18n solution for SvelteKit applications. Currently supported languages:

- **English (en)** - Default/base language
- **German (de)** - German translation

## Setup

The internationalization is implemented using:
- **Paraglide JS 2.0** - Core i18n library
- **Message files** - JSON files containing translations
- **Vite plugin** - For compilation and hot-reloading
- **SvelteKit hooks** - For URL-based language detection

## File Structure

```
project.inlang/                 # Paraglide project configuration
  └── settings.json             # Project settings and module configuration

messages/                       # Translation files
  ├── en.json                   # English messages
  └── de.json                   # German messages

src/lib/paraglide/             # Generated files (do not edit manually)
  ├── messages.js              # Compiled message functions
  ├── runtime.js               # Runtime functions
  ├── server.js                # Server-side utilities
  └── registry.js              # Message registry

src/hooks.server.ts            # Server-side language detection
src/hooks.ts                   # Client-side routing
```

## Language Detection

The app uses URL-based language detection:

- `/` - Default language (English)
- `/de` - German language
- `/de/parent` - German parent dashboard
- `/de/kid` - German kid dashboard

## Adding New Messages

1. **Add to English file** (`messages/en.json`):
```json
{
  "my_new_message": "Hello World",
  "message_with_param": "Hello {name}"
}
```

2. **Add to German file** (`messages/de.json`):
```json
{
  "my_new_message": "Hallo Welt",
  "message_with_param": "Hallo {name}"
}
```

3. **Recompile messages**:
```bash
npx @inlang/paraglide-js compile --project ./project.inlang --outdir ./src/lib/paraglide
```

4. **Use in components**:
```svelte
<script>
  import * as m from '$lib/paraglide/messages.js';
</script>

<h1>{m.my_new_message()}</h1>
<p>{m.message_with_param({ name: 'John' })}</p>
```

## Using Messages in Code

### Basic Usage
```svelte
<script>
  import * as m from '$lib/paraglide/messages.js';
</script>

<h1>{m.app_title()}</h1>
<p>{m.app_tagline()}</p>
```

### With Parameters
```svelte
<script>
  import * as m from '$lib/paraglide/messages.js';
  
  let username = 'John';
</script>

<p>{m.welcome_message({ name: username })}</p>
```

### Getting Current Language
```svelte
<script>
  import { languageTag } from '$lib/paraglide/runtime.js';
</script>

<p>Current language: {languageTag()}</p>
```

## Language Switching

The app includes a language switcher in the navigation bar that:
1. Shows current language
2. Allows switching between available languages
3. Preserves the current page when switching languages

### Implementation
```svelte
<script>
  import { languageTag, locales, localizeHref } from '$lib/paraglide/runtime.js';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
</script>

<select
  value={languageTag()}
  onchange={(e) => {
    const newLang = e.target.value;
    const newUrl = localizeHref($page.url.pathname, { locale: newLang });
    goto(newUrl);
  }}
>
  {#each locales as locale}
    <option value={locale}>
      {locale === 'en' ? 'English' : 'Deutsch'}
    </option>
  {/each}
</select>
```

## Adding New Languages

1. **Update project settings** (`project.inlang/settings.json`):
```json
{
  "baseLocale": "en",
  "locales": ["en", "de", "fr"],
  // ... rest of config
}
```

2. **Create new message file** (`messages/fr.json`):
```json
{
  "$schema": "https://inlang.com/schema/inlang-message-format",
  "app_title": "Application Argent de Poche",
  "app_tagline": "Gérez votre argent de poche facilement",
  // ... all other messages
}
```

3. **Update language switcher** in `+layout.svelte`:
```svelte
<option value={locale}>
  {locale === 'en' ? 'English' : locale === 'de' ? 'Deutsch' : 'Français'}
</option>
```

4. **Recompile messages**:
```bash
npx @inlang/paraglide-js compile --project ./project.inlang --outdir ./src/lib/paraglide
```

## Message Categories

The messages are organized into logical categories:

### App-wide
- `app_title`, `app_tagline`
- `loading`, `redirecting`

### Authentication
- `sign_in`, `sign_up`, `login`, `logout`
- `email`, `password`, `confirm_password`

### Navigation
- `dashboard`, `settings`, `profile`, `transactions`

### Roles
- `parent`, `kid`
- `parent_dashboard`, `kid_dashboard`

### Forms
- `save`, `cancel`, `submit`, `delete`, `edit`, `add`
- `approve`, `reject`, `confirm`

### Transactions
- `transaction_allowance`, `transaction_interest`
- `transaction_withdrawal`, `transaction_deposit`

### Errors
- `error_general`, `error_unauthorized`
- `error_not_found`, `error_validation`

## Development Workflow

1. **Add new messages** to both `en.json` and `de.json`
2. **Recompile** using the npm script: `npx @inlang/paraglide-js compile`
3. **Import and use** messages in components: `import * as m from '$lib/paraglide/messages.js'`
4. **Test** by switching languages in the UI

## Best Practices

1. **Use semantic keys**: `error_validation` instead of `error1`
2. **Group related messages**: Use consistent prefixes like `transaction_*`
3. **Keep messages short**: Avoid very long text in JSON files
4. **Use parameters**: `welcome_user({ name })` instead of multiple messages
5. **Test all languages**: Ensure all messages are translated
6. **Recompile after changes**: Always run the compile command after editing JSON files

## Technical Details

### Vite Configuration
The Vite plugin handles:
- Automatic compilation during development
- Hot reloading of translations
- Tree-shaking of unused messages

### Server-side Rendering
- Language detection works on the server
- Messages are available in server-side code
- No hydration mismatches

### Performance
- Only used messages are bundled
- Automatic tree-shaking
- Minimal runtime overhead
- All languages are currently loaded (will be optimized in future Paraglide versions)

## Troubleshooting

### Message not found
- Check if the message exists in both language files
- Recompile the messages
- Verify the import statement

### Language not switching
- Check the `localizeHref` function usage
- Verify the reroute hook is properly configured
- Check browser network tab for correct URL redirects

### Missing translations
- Ensure all new messages are added to all language files
- Use the same keys in all files
- Check for typos in message keys

## Future Enhancements

- Add more languages (French, Spanish, etc.)
- Implement lazy loading of languages
- Add date/time localization
- Add number formatting localization
- Implement pluralization rules