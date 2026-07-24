# FutureMint AI Design System

> Source: approved competition MVP direction plus the user-provided UI reference analysis. The current student UI combines Flutter-native components with local PNG demo artwork; no image or font is fetched at runtime. Artwork authorship, source, and licence still need to be recorded before public release.
> Page overrides in `pages/<page>.md` take precedence when present.

## Direction

- Audience: students aged 15–18 managing allowance, income, subscriptions, and savings goals.
- Character: optimistic, trustworthy, energetic, and clear; youth-friendly without looking childish.
- Style: the current competition preview starts on a deep-indigo near-black canvas with purple glow, rounded blocks, pill controls, and friendly local mascot artwork. Flutter light mode remains supported, but is not the default presentation in this UI revision.
- Hierarchy: indigo／violet owns the brand, primary actions, selection, and budget Hero; the light foreground owns text and mobile navigation. Sun and orange remain reserved for warning／fallback meaning, while lavender, sky, coral, and pink identify only a small number of feature moments rather than coloring every surface.
- Dials: variance 6/10, motion 2/10, density 5/10.
- Avoid: repeated thick outlines, offset hard shadows, a card around every row, trading-terminal aesthetics, generic multi-hue gradients, glassmorphism, glow on every element, childish fonts, shame-based warnings, decorative charts, and unlicensed or copied third-party illustration.

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
- Phone gutters: 16dp; tablet: 24dp; wide-web gutters: 32dp. Primary signed-in pages use the available post-rail canvas once it reaches 900dp; only focused reading copy inside a surface may keep its own line-length limit.
- Card radius: 20dp; Hero radius: 28dp; input radius: 12dp; buttons and chips: pill.
- Card padding: 16dp on phone, 20–24dp on larger screens.
- Most light cards are flat and borderless. Use a 1dp hairline only when a white surface must be separated from the near-white canvas; reserve a subtle soft shadow for an exceptional floating layer, never for every card. The current dark presentation uses progressively lighter surfaces and restrained purple glow around the Hero for depth.
- Interactive targets are at least 48×48dp with 8dp separation.

## Responsive layout

- Under 720dp: five-item bottom navigation inside a dark rounded shell; Capture remains the central, highest-priority destination.
- 720dp and above: a 264dp NavigationRail; the rail becomes independently scrollable below 560dp height.
- Dashboard switches from a single column to its bento arrangement only when the post-rail content area is at least 900dp wide. Do not use the full viewport width for this decision.
- When the post-rail page area reaches 900dp, primary destinations expand to the full available web canvas instead of appearing as a centred phone-sized App. Below that threshold, 760／840／980dp compact bounds keep forms and lists comfortable. Authentication, recovery, help, settings sheets, and dialogs remain deliberately focused and bounded.
- Use `LayoutBuilder`; do not hardcode device width assumptions.
- Lists reserve padding for persistent navigation and safe areas.
- Support portrait, landscape, browser keyboard navigation, and text scaling to 200% without horizontal overflow.
- Decorative PNG mascots, sparkles, and accent art must occupy reserved layout space or a true background layer. They must not use negative translation, foreground absolute positioning, or fixed page coordinates that can cover headings, money values, form fields, or actions.
- Keep the student-supplied character art visually prominent: use a dedicated hero column, card footer, or wrapped visual band at smaller widths instead of silently shrinking or removing it. The safety requirement is preserving readable content, not making the artwork timid.
- When a segmented choice would no longer fit at a narrow width or 130%+ text scale, replace its one-row presentation with wrapping chips or buttons while preserving the selected value and accessible label.

## Components

- Buttons: one filled pill action per screen; outlined or text styles for alternatives. Loading disables repeat submission and preserves label width.
- `SoftCard`: shared flat rounded surface. Its default is borderless and shadowless; optional hairline and soft elevation are explicit variants. Color communicates hierarchy or feature grouping, never state by itself.
- `PageHeading`: plain color kicker, strong sentence-case title, optional supporting copy, and a trailing action that stacks below 620dp. On light surfaces, feature kickers use the matching `*Ink` token rather than a decorative light accent, preserving the required 4.5:1 text contrast.
- Mascots: `MoneyBuddy` remains available as a Flutter-native decorative companion. The current student UI also uses local PNG mascots for its demo composition; they are decorative, never carry financial state, must stay within their assigned card／artwork area, and must be excluded from semantics or given an accurate label when they become informative.
- Cards: each block has a clear title, one insight, and at most one primary action. Lists use one shared surface with dividers instead of a card for every row.
- Dashboard: one indigo／purple budget Hero, lavender／indigo supportive insight blocks, a sky subscription block, and a neutral recent-record surface. The bento layout appears only with enough content width.
- Capture: the empty/input state gets the colorful Hero; once drafts exist, visual emphasis moves to the first draft and the input Hero becomes quiet.
- Learning: use neighboring or mildly overlapping lavender／indigo blocks at normal text scale; at high text scale they return to a normal vertical stack. Keep a visible free-form coach field with topic and answer-style chips; fixed micro-lesson options remain supplementary.
- Records: analysis comes before the bounded transaction list; use paired income／outflow bars and intent progress, with text summaries that remain understandable without color.
- Notifications: use one icon, title, explanation, optional amount and a clear destination; a renewal notice is a review prompt, never an automatic waste verdict.
- FutureSeed: controls own the emphasis before calculation; presets, sliders and free-form coach input let the learner shape the question. After calculation, three selectable line paths share one unframed chart, with metrics and AI reading companion below. Curves must remain labeled and meaningful without relying only on color.
- Investment lab: show portfolio totals and data freshness before the order form; market examples are a compact selectable list, while holdings and orders use shared surfaces with dividers. Buy/sell is a segmented control, quantity uses stepper/input controls, allocation uses labeled bars, and the event die is a learning prompt rather than a casino visual. Always show source date, fallback state, virtual-money label, and no-advice disclaimer.
- Roles: child／parent uses explicit API authorization and an invite-code family relationship. Parents see only summary cards; never imply transaction-level cross-account visibility. Guest mode has no family controls.
- Forms: visible labels, helper text for financial assumptions, validation after submit/blur, and error text next to the field.
- Capture flow: input → parsing → confirmation. Show provider source and never equate parsed with saved.
- Capture input is text／paste only in this MVP; do not add image upload or OCR controls.
- Navigation: icons and labels from Material Symbols only; active location uses text weight, icon, and an indigo/lavender indicator in addition to color.
- Charts: accessible violet/amber series, direct values, a written summary, empty/loading/error states, and reduced-motion support.
- Authentication: sign-in／register screens use the same dark presentation, one clear primary action, visible password rules, and non-technical retry copy. On a normal-height desktop, the mascot artwork and form stay as one compact vertical group with a 8–32dp gap; guest entry must state that data is temporary before entering the app and remain reachable in a 600dp-high viewport.
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
