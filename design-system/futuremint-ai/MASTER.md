# FutureMint AI Design System

> Source: `ui-ux-pro-max` product, color, UX, and Flutter guidance, curated for the approved competition MVP.
> Page overrides in `pages/<page>.md` take precedence when present.

## Direction

- Audience: students aged 15–18 managing allowance, income, subscriptions, and savings goals.
- Character: optimistic, trustworthy, energetic, and clear; youth-friendly without looking childish.
- Style: vibrant block-based cards with restrained decoration and light mode as the default.
- Dials: variance 4/10, motion 3/10, density 5/10.
- Avoid: trading-terminal aesthetics, neon finance clichés, glass everywhere, childish fonts, shame-based warnings, and decorative charts.

## Semantic colors

### Light

| Token | Value | Purpose |
|---|---|---|
| primary | `#0F766E` | Main actions and selected navigation |
| onPrimary | `#FFFFFF` | Content on primary |
| primaryContainer | `#CCFBF1` | Progress and supportive highlights |
| secondary | `#B45309` | Goal and learning accents |
| secondaryContainer | `#FEF3C7` | Warm opportunity cards |
| background | `#F7FAF9` | App background |
| surface | `#FFFFFF` | Cards and sheets |
| surfaceMuted | `#EAF4F1` | Grouped sections |
| textPrimary | `#12312D` | Main text |
| textSecondary | `#476560` | Supporting text |
| outline | `#B7CCC7` | Borders and dividers |
| success | `#15803D` | Confirmed positive state |
| warning | `#A16207` | Attention with icon/text |
| error | `#B91C1C` | Error with icon/text |

### Dark

| Token | Value | Purpose |
|---|---|---|
| primary | `#5EEAD4` | Main actions and selected navigation |
| onPrimary | `#062B27` | Content on primary |
| primaryContainer | `#134E4A` | Progress and supportive highlights |
| secondary | `#FBBF24` | Goal and learning accents |
| secondaryContainer | `#713F12` | Warm opportunity cards |
| background | `#071A18` | App background |
| surface | `#102724` | Cards and sheets |
| surfaceMuted | `#17332F` | Grouped sections |
| textPrimary | `#F0FDFA` | Main text |
| textSecondary | `#B7D5CF` | Supporting text |
| outline | `#3F5F59` | Borders and dividers |
| success | `#86EFAC` | Confirmed positive state |
| warning | `#FDE68A` | Attention with icon/text |
| error | `#FCA5A5` | Error with icon/text |

Every foreground/background pair used for body text must meet WCAG 4.5:1. State meaning always includes text or an icon, never color alone.

## Typography

- Use the platform sans-serif with Traditional Chinese fallback; do not fetch a font at runtime.
- Display: 32/40, weight 700.
- Headline: 24/32, weight 700.
- Title: 20/28, weight 600.
- Body: 16/24, weight 400.
- Label: 14/20, weight 600.
- Caption: 12/18, weight 500; never use below 12.
- Money and chart values use tabular figures.
- Long text stays within 65–75 characters on wide screens.

## Spacing, shape, and elevation

- Spacing tokens: 4, 8, 12, 16, 24, 32, 48, 64dp.
- Phone gutters: 16dp; tablet: 24dp; desktop content max width: 1200dp.
- Card radius: 20dp; input/button radius: 14dp; chips: pill.
- Card padding: 16dp on phone, 20–24dp on larger screens.
- Prefer borders and tonal surfaces; use only two subtle elevation levels.
- Interactive targets are at least 48×48dp with 8dp separation.

## Responsive layout

- Under 720dp: five-item bottom navigation with a prominent center Capture action.
- 720–1099dp: NavigationRail and a single responsive content column.
- 1100dp and above: NavigationRail plus a two-column dashboard; content remains bounded.
- Use `LayoutBuilder`; do not hardcode device width assumptions.
- Lists reserve padding for persistent navigation and safe areas.
- Support portrait, landscape, browser keyboard navigation, and text scaling to 200% without horizontal overflow.

## Components

- Buttons: one filled primary action per screen; outlined or text styles for alternatives. Loading disables repeat submission and preserves label width.
- Cards: tonal blocks with clear title, one insight, and one action. Not every card is clickable.
- Forms: visible labels, helper text for financial assumptions, validation after submit/blur, and error text next to the field.
- Capture flow: input → parsing → confirmation. Show provider source and never equate parsed with saved.
- Navigation: icons and labels from Material Symbols only; active location uses color, weight, and indicator.
- Charts: accessible teal/amber series, direct values, a written summary, empty/loading/error states, and reduced-motion support.
- Feedback: snackbars use polite announcements; destructive reset requires confirmation and offers a clear consequence statement.

## Motion

- Micro-interactions: 150–250ms, ease-out on entrance and faster ease-in on exit.
- Animate opacity and transform only; no layout-shifting scale or height animation.
- Limit each screen to one or two meaningful motions.
- Respect platform reduced-motion settings and keep the interface fully usable with animation disabled.

## Required states

Every remote or persisted feature provides loading, success, empty, validation error, retryable error, offline, and disabled states. Connected mode failures never silently substitute demo data; switching to Offline demo is an explicit user action.

## Delivery checks

- No Emoji used as structural icons.
- All controls have semantic labels, roles, selected/disabled states, and logical focus order.
- Touch targets meet 48dp and focus indicators remain visible on Web.
- Verify 375px, 768px, 1024px, and 1440px widths, plus landscape.
- Verify light/dark contrast, 200% text scale, keyboard navigation, reduced motion, and no content hidden behind navigation.
