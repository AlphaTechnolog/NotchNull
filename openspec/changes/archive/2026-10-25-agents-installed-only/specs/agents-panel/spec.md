# Spec Delta

## Purpose

Defines how the notch's Agents tab arranges provider limits and live sessions so they read as a stable list: intrinsic heights, top alignment, blank space below, and empty states that explain what is missing.

## ADDED Requirements

### Requirement: Provider blocks keep their intrinsic height

The Agents tab SHALL lay out each visible provider usage block at the height its content needs. Blocks SHALL NOT expand to divide the card's available height.

#### Scenario: One provider stays at the top
- **WHEN** only one provider is visible
- **THEN** its block appears at the top of the card and the remaining height is blank below it

#### Scenario: Two providers do not split the card in half
- **WHEN** two providers are visible
- **THEN** each block keeps its own content height and the blocks stack without dividing the card into equal halves

#### Scenario: Three providers stack
- **WHEN** three providers are visible
- **THEN** all three stack in order and any spare height remains below the last block

### Requirement: Session rows keep their intrinsic height

The Sessions column SHALL lay out session rows at their existing compact row height and SHALL NOT stretch a row to fill spare vertical space.

#### Scenario: One session sits at the top
- **WHEN** one session is listed
- **THEN** the session row appears directly below the Sessions header and blank space remains below it

#### Scenario: Several sessions remain a compact list
- **WHEN** multiple sessions are listed
- **THEN** the rows stack with their normal spacing instead of expanding to share the column height

### Requirement: Both Agents columns are top-aligned

The provider column and the Sessions column SHALL align their content to the top of their cards. Spare height SHALL collect below the content rather than being split above and below it.

#### Scenario: Short content leaves the bottom blank
- **WHEN** either column has less content than the panel height allows
- **THEN** the content starts at the top and the blank area is at the bottom of that card

### Requirement: Separators follow the visible providers

Dividers in the provider column SHALL appear only between visible provider blocks and visible plan blocks.

#### Scenario: Hidden provider leaves no leading divider
- **WHEN** the first provider is hidden and another provider or plan is visible
- **THEN** the column starts with that visible content and does not render a stray divider above it

#### Scenario: Hidden provider leaves no trailing divider
- **WHEN** the last visible provider is followed only by blank space
- **THEN** no divider is rendered below it

### Requirement: Empty Agents states explain what to install

When no coding agent is installed, the provider column SHALL show an empty state naming the agents NotchNull can watch and how to make them appear. The Sessions column SHALL explain that live sessions appear after an installed agent runs.

#### Scenario: Nothing installed
- **WHEN** no coding agent is installed and the user opens the Agents tab
- **THEN** the provider card says that no coding agents were found, the session card says no live sessions exist, and both point to installing or running a supported agent

#### Scenario: Some agents installed but none running
- **WHEN** at least one coding agent is installed and no session is active
- **THEN** the session empty state names only the installed agents that can appear there

### Requirement: Overflowing content still scrolls

The Agents tab SHALL keep its existing scroll behavior: content that fits is shown without stretching, and content taller than the available height scrolls.

#### Scenario: Content taller than the panel
- **WHEN** the visible providers and plans are taller than the card
- **THEN** the column scrolls and does not compress blocks below their content height

#### Scenario: Content fits
- **WHEN** the visible content fits in the card
- **THEN** no scroll indicator or fade is shown and the content stays top-aligned

### Requirement: Agents panel requests the height its columns need

The Agents tab SHALL measure the intrinsic height of its visible provider/plan column and its session column, use the taller one, and add the card and panel padding to request the open panel's content height.

#### Scenario: One provider shrinks the panel
- **WHEN** the Agents tab shows one provider and a short session list
- **THEN** the open panel shrinks to the taller column plus padding instead of keeping the configured height's blank area

#### Scenario: Sessions column dominates
- **WHEN** the session list needs more height than the provider column
- **THEN** the fitted height follows the taller session column

#### Scenario: Empty states fit
- **WHEN** no agents are installed and the empty states are visible
- **THEN** the panel fits the empty-state content rather than the configured height

#### Scenario: Content changes while visible
- **WHEN** providers, plans or sessions appear or disappear while the Agents tab is open
- **THEN** the height request updates to the new taller column plus padding

### Requirement: Fitted Agents height is capped

The requested Agents height SHALL be capped by the user's configured open-panel height and the body canvas. Content taller than the cap SHALL scroll rather than grow the panel beyond it.

#### Scenario: Content exceeds the configured height
- **WHEN** the taller Agents column needs more height than the configured panel height
- **THEN** the panel stays at the configured height and the columns scroll

#### Scenario: User lowers the height while Agents is open
- **WHEN** the configured panel height is lowered below the fitted height
- **THEN** the panel resizes to the new maximum and keeps the columns scrollable

#### Scenario: Canvas limit
- **WHEN** the fitted height would exceed the body canvas
- **THEN** the body is clamped to the canvas as before

### Requirement: Fitted height applies only while Agents is visible

Other tabs SHALL keep the configured open-panel content height. Returning to Agents SHALL reapply its fitted height without changing the stored preference.

#### Scenario: Leaving Agents
- **WHEN** the user switches from Agents to another tab
- **THEN** that tab uses the configured open-panel height

#### Scenario: Returning to Agents
- **WHEN** the user switches back to Agents
- **THEN** the fitted Agents height applies again and the configured preference is unchanged

#### Scenario: Agents becomes unavailable
- **WHEN** the Agents tab is hidden or disabled while selected
- **THEN** the visible fallback tab uses its own configured height
