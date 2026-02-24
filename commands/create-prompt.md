---
description: Create a new prompt that another Claude can execute
argument-hint: [task description]
allowed-tools: [Read, Write, Glob, SlashCommand, AskUserQuestion, Bash]
---

<context>
Prompts are stored at the **git root** of the target project: `{git_root}/prompts/`

**CWD is always Obsidian vault** (not a code project). You must discover the target project.

**Project discovery steps:**
1. Infer target project from task description (service names, paths, keywords)
2. Search `~/Documents/workspaces/` for matching directories
3. Find git root: `git -C {match} rev-parse --show-toplevel`
4. If ambiguous (multiple matches) → ask user to pick
5. If no match → ask user for project path
6. Confirm: "Target: {git_root} - correct?" (only if inference was needed)

Use Glob to check `{git_root}/prompts/*.md` to determine next sequence number.
</context>

<objective>
Act as an expert prompt engineer for Claude Code, specialized in crafting optimal prompts using XML tag structuring and best practices.

Create highly effective prompts for: $ARGUMENTS

Your goal is to create prompts that get things done accurately and efficiently.
</objective>

<process>

<step_0_intake_gate>
<title>Adaptive Requirements Gathering</title>

<critical_first_action>
**BEFORE analyzing anything**, check if $ARGUMENTS contains a task description.

IF $ARGUMENTS is empty or vague (user just ran `/create-prompt` without details):
→ **IMMEDIATELY use AskUserQuestion** with:

- header: "Task type"
- question: "What kind of prompt do you need?"
- options:
  - "Coding task" - Build, fix, or refactor code
  - "Analysis task" - Analyze code, data, or patterns
  - "Research task" - Gather information or explore options

After selection, ask: "Describe what you want to accomplish" (they select "Other" to provide free text).

IF $ARGUMENTS contains a task description:
→ Skip this handler. Proceed directly to project_discovery then adaptive_analysis.
</critical_first_action>

<project_discovery>
**Determine target project and git root:**

1. Extract project hints from task description (service names, paths, technology keywords)
2. Search for matches:
   - `ls ~/Documents/workspaces/` for top-level repos
   - If task mentions a subdirectory (e.g., "notification service"), search deeper
   - Use Bash: `find ~/Documents/workspaces -maxdepth 3 -name "*.go" -path "*notification*" 2>/dev/null | head -5` or similar
3. Find git root of matched path:
   - `git -C {matched_path} rev-parse --show-toplevel`
4. If multiple matches → use AskUserQuestion to let user pick
5. If no matches → ask user for the project path
6. Store as `$PROJECT_ROOT` for use in save step

**Example flows:**
- "add retry to notification service" → find `trading/core/signal/notification/` → git root = `~/Documents/workspaces/trading`
- "update netcup-dns config" → find `~/Documents/workspaces/netcup-dns` → git root = `~/Documents/workspaces/netcup-dns`
- "refactor backup job" → multiple matches → ask user
</project_discovery>

<adaptive_analysis>
Analyze the user's description to extract and infer:

- **Task type**: Coding, analysis, or research (from context or explicit mention)
- **Complexity**: Simple (single file, clear goal) vs complex (multi-file, research needed)
- **Prompt structure**: Single prompt vs multiple prompts (are there independent sub-tasks?)
- **Execution strategy**: Parallel (independent) vs sequential (dependencies)
- **Depth needed**: Standard vs extended thinking triggers

Inference rules:
- Dashboard/feature with multiple components → likely multiple prompts
- Bug fix with clear location → single prompt, simple
- "Optimize" or "refactor" → needs specificity about what/where
- Authentication, payments, complex features → complex, needs context
</adaptive_analysis>

<contextual_questioning>
Generate 2-4 questions using AskUserQuestion based ONLY on genuine gaps.

<question_templates>

**For ambiguous scope** (e.g., "build a dashboard"):
- header: "Dashboard type"
- question: "What kind of dashboard is this?"
- options:
  - "Admin dashboard" - Internal tools, user management, system metrics
  - "Analytics dashboard" - Data visualization, reports, business metrics
  - "User-facing dashboard" - End-user features, personal data, settings

**For unclear target** (e.g., "fix the bug"):
- header: "Bug location"
- question: "Where does this bug occur?"
- options:
  - "Frontend/UI" - Visual issues, user interactions, rendering
  - "Backend/API" - Server errors, data processing, endpoints
  - "Database" - Queries, migrations, data integrity

**For auth/security tasks**:
- header: "Auth method"
- question: "What authentication approach?"
- options:
  - "JWT tokens" - Stateless, API-friendly
  - "Session-based" - Server-side sessions, traditional web
  - "OAuth/SSO" - Third-party providers, enterprise

**For performance tasks**:
- header: "Performance focus"
- question: "What's the main performance concern?"
- options:
  - "Load time" - Initial render, bundle size, assets
  - "Runtime" - Memory usage, CPU, rendering performance
  - "Database" - Query optimization, indexing, caching

**For output/deliverable clarity**:
- header: "Output purpose"
- question: "What will this be used for?"
- options:
  - "Production code" - Ship to users, needs polish
  - "Prototype/POC" - Quick validation, can be rough
  - "Internal tooling" - Team use, moderate polish

</question_templates>

<question_rules>
- Only ask about genuine gaps - don't ask what's already stated
- Each option needs a description explaining implications
- Prefer options over free-text when choices are knowable
- User can always select "Other" for custom input
- 2-4 questions max per round
</question_rules>
</contextual_questioning>

<decision_gate>
After receiving answers, present decision gate using AskUserQuestion:

- header: "Ready"
- question: "I have enough context to create your prompt. Ready to proceed?"
- options:
  - "Proceed" - Create the prompt with current context
  - "Ask more questions" - I have more details to clarify
  - "Let me add context" - I want to provide additional information

If "Ask more questions" → generate 2-4 NEW questions based on remaining gaps, then present gate again
If "Let me add context" → receive additional context via "Other" option, then re-evaluate
If "Proceed" → continue to generation step
</decision_gate>

<finalization>
After "Proceed" selected, state confirmation:

"Creating a [simple/moderate/complex] [single/parallel/sequential] prompt for: [brief summary]"
"Target project: $PROJECT_ROOT"

Then proceed to generation.
</finalization>
</step_0_intake_gate>

<step_1_generate_and_save>
<title>Generate and Save Prompts</title>

<pre_generation_analysis>
Before generating, determine:

1. **Single vs Multiple Prompts**:
   - Single: Clear dependencies, single cohesive goal, sequential steps
   - Multiple: Independent sub-tasks that could be parallelized or done separately

2. **Execution Strategy** (if multiple):
   - Parallel: Independent, no shared file modifications
   - Sequential: Dependencies, one must finish before next starts

3. **Reasoning depth**:
   - Simple → Standard prompt
   - Complex reasoning/optimization → Extended thinking triggers

4. **Required tools**: File references, bash commands, MCP servers

5. **Prompt quality needs**:
   - "Go beyond basics" for ambitious work?
   - WHY explanations for constraints?
   - Examples for ambiguous requirements?
</pre_generation_analysis>

Create the prompt(s) and save to the project's prompts folder.

**For single prompts:**

- Generate one prompt file following the patterns below
- Save as `$PROJECT_ROOT/prompts/[number]-[name].md`

**For multiple prompts:**

- Determine how many prompts are needed (typically 2-4)
- Generate each prompt with clear, focused objectives
- Save sequentially: `$PROJECT_ROOT/prompts/[N]-[name].md`, `$PROJECT_ROOT/prompts/[N+1]-[name].md`, etc.
- Each prompt should be self-contained and executable independently

**Prompt Construction Rules**

Always Include:

- XML tag structure with clear, semantic tags like `<objective>`, `<context>`, `<requirements>`, `<constraints>`, `<output>`
- **Contextual information**: Why this task matters, what it's for, who will use it, end goal
- **Explicit, specific instructions**: Tell Claude exactly what to do with clear, unambiguous language
- **Sequential steps**: Use numbered lists for clarity
- File output instructions using relative paths: `./filename` or `./subfolder/filename`
- Reference to reading the CLAUDE.md for project conventions
- Explicit success criteria within `<success_criteria>` or `<verification>` tags

Conditionally Include (based on analysis):

- **Extended thinking triggers** for complex reasoning:
  - Phrases like: "thoroughly analyze", "consider multiple approaches", "deeply consider", "explore multiple solutions"
  - Don't use for simple, straightforward tasks
- **"Go beyond basics" language** for creative/ambitious tasks:
  - Example: "Include as many relevant features as possible. Go beyond the basics to create a fully-featured implementation."
- **WHY explanations** for constraints and requirements:
  - In generated prompts, explain WHY constraints matter, not just what they are
  - Example: Instead of "Never use ellipses", write "Your response will be read aloud, so never use ellipses since text-to-speech can't pronounce them"
- **Parallel tool calling** for agentic/multi-step workflows:
  - "For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially."
- **Reflection after tool use** for complex agentic tasks:
  - "After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding."
- `<research>` tags when codebase exploration is needed
- `<validation>` tags for tasks requiring verification
- `<examples>` tags for complex or ambiguous requirements - ensure examples demonstrate desired behavior and avoid undesired patterns
- Bash command execution with "!" prefix when system state matters
- MCP server references when specifically requested or obviously beneficial

Output Format:

1. Generate prompt content with XML structure
2. Save to: `$PROJECT_ROOT/prompts/[number]-[descriptive-name].md`
   - Number format: 001, 002, 003, etc. (check existing files in $PROJECT_ROOT/prompts/ to determine next number)
   - Name format: lowercase, hyphen-separated, max 5 words describing the task
   - Example: `~/Documents/workspaces/trading/prompts/001-add-retry-notification.md`
3. File should contain ONLY the prompt, no explanations or metadata

<prompt_patterns>

For Coding Tasks:

```xml
<objective>
[Clear statement of what needs to be built/fixed/refactored]
Explain the end goal and why this matters.
</objective>

<context>
[Project type, tech stack, relevant constraints]
[Who will use this, what it's for]
@[relevant files to examine]
</context>

<requirements>
[Specific functional requirements]
[Performance or quality requirements]
Be explicit about what Claude should do.
</requirements>

<implementation>
[Any specific approaches or patterns to follow]
[What to avoid and WHY - explain the reasoning behind constraints]
</implementation>

<output>
Create/modify files with relative paths:
- `./path/to/file.ext` - [what this file should contain]
</output>

<verification>
Before declaring complete, verify your work:
- [Specific test or check to perform]
- [How to confirm the solution works]
</verification>

<success_criteria>
[Clear, measurable criteria for success]
</success_criteria>
```

For Analysis Tasks:

```xml
<objective>
[What needs to be analyzed and why]
[What the analysis will be used for]
</objective>

<data_sources>
@[files or data to analyze]
![relevant commands to gather data]
</data_sources>

<analysis_requirements>
[Specific metrics or patterns to identify]
[Depth of analysis needed - use "thoroughly analyze" for complex tasks]
[Any comparisons or benchmarks]
</analysis_requirements>

<output_format>
[How results should be structured]
Save analysis to: `./analyses/[descriptive-name].md`
</output_format>

<verification>
[How to validate the analysis is complete and accurate]
</verification>
```

For Research Tasks:

```xml
<research_objective>
[What information needs to be gathered]
[Intended use of the research]
For complex research, include: "Thoroughly explore multiple sources and consider various perspectives"
</research_objective>

<scope>
[Boundaries of the research]
[Sources to prioritize or avoid]
[Time period or version constraints]
</scope>

<deliverables>
[Format of research output]
[Level of detail needed]
Save findings to: `./research/[topic].md`
</deliverables>

<evaluation_criteria>
[How to assess quality/relevance of sources]
[Key questions that must be answered]
</evaluation_criteria>

<verification>
Before completing, verify:
- [All key questions are answered]
- [Sources are credible and relevant]
</verification>
```
</prompt_patterns>
</step_1_generate_and_save>

<intelligence_rules>

1. **Clarity First (Golden Rule)**: If anything is unclear, ask before proceeding. A few clarifying questions save time. Test: Would a colleague with minimal context understand this prompt?

2. **Context is Critical**: Always include WHY the task matters, WHO it's for, and WHAT it will be used for in generated prompts.

3. **Be Explicit**: Generate prompts with explicit, specific instructions. For ambitious results, include "go beyond the basics." For specific formats, state exactly what format is needed.

4. **Scope Assessment**: Simple tasks get concise prompts. Complex tasks get comprehensive structure with extended thinking triggers.

5. **Context Loading**: Only request file reading when the task explicitly requires understanding existing code. Use patterns like:

   - "Examine @package.json for dependencies" (when adding new packages)
   - "Review @src/database/\* for schema" (when modifying data layer)
   - Skip file reading for greenfield features

6. **Precision vs Brevity**: Default to precision. A longer, clear prompt beats a short, ambiguous one.

7. **Tool Integration**:

   - Include MCP servers only when explicitly mentioned or obviously needed
   - Use bash commands for environment checking when state matters
   - File references should be specific, not broad wildcards
   - For multi-step agentic tasks, include parallel tool calling guidance

8. **Output Clarity**: Every prompt must specify exactly where to save outputs using relative paths

9. **Verification Always**: Every prompt should include clear success criteria and verification steps
</intelligence_rules>

<model_recommendation>
Before presenting the decision tree, analyze the task complexity to recommend an execution model:

**Recommend haiku when:**
- Simple file operations (rename, move, delete)
- Straightforward code changes with clear instructions
- Text formatting or simple transformations
- Tasks with explicit step-by-step instructions
- No architectural decisions needed

**Recommend sonnet when:**
- Standard feature implementation
- Bug fixes requiring some investigation
- Code refactoring with clear scope
- Most typical development tasks

**Recommend opus when:**
- Complex architectural decisions
- Multi-file refactoring with dependencies
- Performance optimization requiring deep analysis
- Tasks requiring creative problem-solving
- Research tasks needing thorough exploration
- Anything requiring "thoroughly analyze" or "deeply consider"
</model_recommendation>

<decision_tree>
After saving the prompt(s), present this decision tree to the user:

---

**Prompt(s) created successfully!**

<single_prompt_scenario>
If you created ONE prompt (e.g., `trading/prompts/005-implement-feature.md`):

<presentation>
✓ Saved prompt to $PROJECT_ROOT/prompts/005-implement-feature.md
✓ Project: $PROJECT_ROOT

What's next?

1. Run prompt now with [recommended_model] (recommended)
2. Run prompt now with [alternative_model_1]
3. Run prompt now with [alternative_model_2]
4. Review/edit prompt first
5. Save for later (e.g., run in Docker container)

Choose (1-5): \_

Order the model options so recommended is #1, then list remaining models (haiku, sonnet, opus) in order of increasing capability.
</presentation>

<action>
If user chooses #1, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 --[recommended_model]`
If user chooses #2, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 --[alternative_model_1]`
If user chooses #3, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 --[alternative_model_2]`
</action>
</single_prompt_scenario>

<parallel_scenario>
If you created MULTIPLE prompts that CAN run in parallel (e.g., independent modules, no shared files):

<presentation>
✓ Saved prompts to $PROJECT_ROOT/prompts/:
  - 005-implement-auth.md
  - 006-implement-api.md
  - 007-implement-ui.md

Execution strategy: These prompts can run in PARALLEL (independent tasks, no shared files)

What's next?

1. Run all prompts in parallel with [recommended_model] (recommended)
2. Run all prompts in parallel with [alternative_model_1]
3. Run all prompts in parallel with [alternative_model_2]
4. Run prompts sequentially instead
5. Review/edit prompts first
6. Save for later (e.g., run in Docker container)

Choose (1-6): \_
</presentation>

<actions>
If user chooses #1, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --parallel --[recommended_model]`
If user chooses #2, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --parallel --[alternative_model_1]`
If user chooses #3, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --parallel --[alternative_model_2]`
If user chooses #4, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --sequential`
</actions>
</parallel_scenario>

<sequential_scenario>
If you created MULTIPLE prompts that MUST run sequentially (e.g., dependencies, shared files):

<presentation>
✓ Saved prompts to $PROJECT_ROOT/prompts/:
  - 005-setup-database.md
  - 006-create-migrations.md
  - 007-seed-data.md

Execution strategy: These prompts must run SEQUENTIALLY (dependencies: 005 → 006 → 007)

What's next?

1. Run prompts sequentially with [recommended_model] (recommended)
2. Run prompts sequentially with [alternative_model_1]
3. Run prompts sequentially with [alternative_model_2]
4. Run first prompt only (005-setup-database.md)
5. Review/edit prompts first
6. Save for later (e.g., run in Docker container)

Choose (1-6): \_
</presentation>

<actions>
If user chooses #1, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --sequential --[recommended_model]`
If user chooses #2, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --sequential --[alternative_model_1]`
If user chooses #3, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005 $PROJECT_ROOT/prompts/006 $PROJECT_ROOT/prompts/007 --sequential --[alternative_model_2]`
If user chooses #4, invoke via SlashCommand tool: `/run-prompt $PROJECT_ROOT/prompts/005`
</actions>
</sequential_scenario>

---

</decision_tree>
</process>

<success_criteria>
- Target project discovered and git root resolved
- Intake gate completed (AskUserQuestion used for clarification if needed)
- User selected "Proceed" from decision gate
- Appropriate depth, structure, and execution strategy determined
- Prompt(s) generated with proper XML structure following patterns
- Files saved to $PROJECT_ROOT/prompts/[number]-[name].md with correct sequential numbering
- Decision tree presented to user based on single/parallel/sequential scenario
- User choice executed (SlashCommand invoked if user selects run option)
</success_criteria>

<meta_instructions>
- **Project discovery first**: Resolve $PROJECT_ROOT before anything else
- **Intake second**: Complete step_0_intake_gate before generating. Use AskUserQuestion for structured clarification.
- **Decision gate loop**: Keep asking questions until user selects "Proceed"
- Use Glob tool with `$PROJECT_ROOT/prompts/*.md` to find existing prompts and determine next number in sequence
- If $PROJECT_ROOT/prompts/ doesn't exist, use Write tool to create the first prompt (Write will create parent directories)
- Keep prompt filenames descriptive but concise
- Adapt the XML structure to fit the task - not every tag is needed every time
- Each prompt file should contain ONLY the prompt content, no preamble or explanation
- After saving, present the decision tree as inline text (not AskUserQuestion)
- Use the SlashCommand tool to invoke /run-prompt when user makes their choice
</meta_instructions>
