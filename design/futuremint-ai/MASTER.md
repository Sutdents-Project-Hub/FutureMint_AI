# FutureMint AI Design System

> Source: approved competition MVP direction plus the user-provided UI reference analysis, implemented with Flutter-native shapes and no external visual assets.
> Page overrides in `pages/<page>.md` take precedence when present.

## Direction

- Audience: students aged 15–18 managing allowance, income, subscriptions, and savings goals.
- Character: optimistic, trustworthy, energetic, and clear; youth-friendly without looking childish.
- Style: calm lavender-tinted near-white canvas, flat rounded color blocks, deep-indigo action anchors, pill controls, and friendly geometric companions. It combines the clean planner structure of the reference UI with its expressive habit-app color and character language; light mode is the primary competition presentation.
- Hierarchy: indigo／violet owns the brand, primary actions, selection, and budget Hero; deep ink owns text and mobile navigation. Sun and orange are reserved for warning／fallback meaning, while lavender, sky, coral, and pink identify only a small number of feature moments rather than coloring every surface.
- Dials: variance 6/10, motion 2/10, density 5/10.
- Avoid: repeated thick outlines, offset hard shadows, a card around every row, trading-terminal aesthetics, generic multi-hue gradients, glassmorphism, neon everywhere, childish fonts, shame-based warnings, decorative charts, and copied third-party illustration.

## Semantic colors

### Light

| Token | Value | Purpose |
|---|---|---|
| ink | `#1B1B2A` | Text, selected-control foreground, and phone navigation |
| background | `#F8F7FC` | Near-white canvas with a restrained lavender tint |
| surface | `#FFFFFF` | Neutral cards, sheets, list surfaces, and fields |
| mint | `#6D5BD0` | Indigo primary action, Budget Hero, brand mark, and confirmed emphasis |
| mintSoft | `#E8E4FF` | Flutter compatibility token for indigo supportive and selected surfaces |
| teal | `#4B3FA7` | Flutter compatibility token for violet links, progress, and restrained brand labels |
| tealDark | `#342B7C` | Flutter compatibility token for high-contrast violet text or progress |
| coral | `#F96F61` | Coach and interaction accents |
| coralSoft | `#FFE0DC` | Gentle feedback surfaces |
| sun | `#F7C94C` | Warning signal and spark companion |
| sunSoft | `#FFF0B8` | Warning and fallback-data surfaces only |
| lavender | `#A58CE8` | Personalized learning accent |
| lavenderInk | `#6953A7` | Accessible learning label text on light surfaces |
| lavenderSoft | `#EAE4FC` | Learning and coach surfaces |
| periwinkle | `#8EA4E7` | Habit-style example and secondary feature accent |
| periwinkleSoft | `#E4E9FB` | Learning example surface |
| sky | `#80C5EC` | Records and information accent |
| skyInk | `#2B6587` | Accessible records and information label text on light surfaces |
| skySoft | `#E0F2FB` | Records and FutureSeed surfaces |
| orange | `#FFB34D` | Subscription option accent only |
| orangeSoft | `#FFE4BC` | Subscription option surfaces only |
| pink | `#E879C9` | Small expressive companion or option accent |
| pinkSoft | `#F8DDF0` | Small expressive surface |
| coralInk | `#B23A32` | Accessible coach label text on light surfaces |
| hairline | `#DEDDEC` | Dividers and optional card boundaries |
| outline | `#74728C` | Inputs and secondary controls |
| success | `#117A4B` | Confirmed positive state |
| warning | `#A85B00` | Attention with icon/text |
| error | `#B42318` | Error with icon/text |

### Dark

| Token | Value | Purpose |
|---|---|---|
| background | `#14131F` | Deep-indigo near-black canvas |
| surface | `#1C1B2A` | Base card and sheet surface |
| surfaceRaised | `#28263A` | Higher purple-gray grouped surface; depth comes from lightness |
| primary | `#B8AEFF` | Main actions and progress |
| primaryContainer | `#393368` | Selected or supportive state |
| secondary | `#C3BCFF` | Supporting violet accent |
| secondaryContainer | `#64302C` | Feedback surface |
| textPrimary | `#FFF8EE` | Main text |
| outline | `#AAA8C0` | Strong component outline |
| outlineMuted | `#464459` | Dividers and inactive outline |
| feature accents | light palette, selectively reused | Small icons and selected indicators only |

Every foreground/background pair used for body text must meet WCAG 4.5:1. State meaning always includes text or an icon, never color alone.

## Typography

- Use the platform sans-serif with Traditional Chinese fallback; do not fetch a font at runtime.
- Display: 34–42/38–46, weight 800.
- Headline: 26–32/30–36, weight 700.
- Title: 18–22/24–28, weight 700.
- Body: 16/24, weight 400.
- Label: 14/20, weight 700.
- Caption: 12/18, weight 500; never use below 12.
- Money and chart values use tabular figures.
- Long text stays within 65–75 characters on wide screens.

## Spacing, shape, and elevation

- Spacing tokens: 4, 8, 12, 16, 24, 32, 48, 64dp.
- Phone gutters: 16dp; tablet: 24dp; desktop content max width: 1200dp.
- Card radius: 20dp; Hero radius: 28dp; input radius: 12dp; buttons and chips: pill.
- Card padding: 16dp on phone, 20–24dp on larger screens.
- Most light cards are flat and borderless. Use a 1dp hairline only when a white surface must be separated from the near-white canvas; reserve a subtle soft shadow for an exceptional floating layer, never for every card. Dark mode uses progressively lighter surfaces for depth.
- Interactive targets are at least 48×48dp with 8dp separation.

## Responsive layout

- Under 720dp: five-item bottom navigation inside a dark rounded shell; Capture remains the central, highest-priority destination.
- 720dp and above: a 264dp NavigationRail; the rail becomes independently scrollable below 560dp height.
- Dashboard switches from a single column to its bento arrangement only when the post-rail content area is at least 900dp wide. Do not use the full viewport width for this decision.
- Page content remains bounded to 1200dp; reading/list surfaces use narrower 760／840／980dp bounds where appropriate.
- Use `LayoutBuilder`; do not hardcode device width assumptions.
- Lists reserve padding for persistent navigation and safe areas.
- Support portrait, landscape, browser keyboard navigation, and text scaling to 200% without horizontal overflow.

## Components

- Buttons: one filled pill action per screen; outlined or text styles for alternatives. Loading disables repeat submission and preserves label width.
- `SoftCard`: shared flat rounded surface. Its default is borderless and shadowless; optional hairline and soft elevation are explicit variants. Color communicates hierarchy or feature grouping, never state by itself.
- `PageHeading`: plain color kicker, strong sentence-case title, optional supporting copy, and a trailing action that stacks below 620dp. On light surfaces, feature kickers use the matching `*Ink` token rather than a decorative light accent, preserving the required 4.5:1 text contrast.
- `MoneyBuddy`: Flutter-native blob, flower, or spark companion with a single-hue radial highlight, black facial features, and the semantic label `FutureMint 金錢夥伴`. It is decorative and never carries financial state.
- Cards: each block has a clear title, one insight, and at most one primary action. Lists use one shared surface with dividers instead of a card for every row.
- Dashboard: one indigo budget Hero, lavender／indigo supportive insight blocks, a sky subscription block, and a neutral recent-record surface. The bento layout appears only with enough content width.
- Capture: the empty/input state gets the colorful Hero; once drafts exist, visual emphasis moves to the first draft and the input Hero becomes quiet.
- Learning: use neighboring or mildly overlapping lavender／indigo blocks at normal text scale; at high text scale they return to a normal vertical stack.
- Records: analysis comes before the bounded transaction list; use paired income／outflow bars and intent progress, with text summaries that remain understandable without color.
- Notifications: use one icon, title, explanation, optional amount and a clear destination; a renewal notice is a review prompt, never an automatic waste verdict.
- FutureSeed: controls own the emphasis before calculation; after calculation, three selectable line paths share one unframed chart, with metrics and AI reading companion below. Curves must remain labeled and meaningful without relying only on color.
- Investment lab: show portfolio totals and data freshness before the order form; market examples are a compact selectable list, while holdings and orders use shared surfaces with dividers. Buy/sell is a segmented control, quantity uses stepper/input controls, allocation uses labeled bars, and the event die is a learning prompt rather than a casino visual. Always show source date, fallback state, virtual-money label, and no-advice disclaimer.
- Roles: child／parent changes copy and education framing only; never imply cross-account visibility unless authorization and data relationships are implemented.
- Forms: visible labels, helper text for financial assumptions, validation after submit/blur, and error text next to the field.
- Capture flow: input → parsing → confirmation. Show provider source and never equate parsed with saved.
- Navigation: icons and labels from Material Symbols only; active location uses text weight, icon, and an indigo/lavender indicator in addition to color.
- Charts: accessible violet/amber series, direct values, a written summary, empty/loading/error states, and reduced-motion support.
- Authentication: sign-in／register screens use the same calm canvas, one clear primary action, visible password rules, and non-technical retry copy. Guest entry must state that data is temporary before entering the app.
- Account state: App shell shows signed-in or guest state with text and icon. Guest state has a persistent, wrapping notice that data is not stored; logout／leave guest is available in Settings.
- Feedback: snackbars use polite announcements. Network or authentication failure never fabricates a saved result or switches data sources silently.

## Motion

- Micro-interactions: 150–250ms, ease-out on entrance and faster ease-in on exit.
- Animate opacity and transform only; no layout-shifting scale or height animation.
- Limit each screen to one or two meaningful motions.
- Destination changes, navigation selection, and chart data updates are immediate; they do not use horizontal route slides or delayed interpolation.
- Respect platform reduced-motion settings and keep the interface fully usable with animation disabled.

## Required states

Every remote or persisted feature provides loading, success, empty, validation error, retryable error, unavailable-network, and disabled states. API failure never silently substitutes demo data. Guest mode is an explicit temporary state, not an offline synchronization mode.

## Delivery checks

- No Emoji used as structural icons.
- All controls have semantic labels, roles, selected/disabled states, and logical focus order.
- Touch targets meet 48dp and focus indicators remain visible on Web.
- Verify 375px, 768px, 1024px, and 1440px widths, plus landscape.
- Verify light/dark contrast, 200% text scale, keyboard navigation, reduced motion, and no content hidden behind navigation.
