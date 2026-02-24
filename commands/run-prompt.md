---
name: run-prompt
description: Delegate one or more prompts to fresh sub-task contexts with parallel or sequential execution
argument-hint: <prompt-number(s)-or-path> [--parallel|--sequential] [--haiku|--sonnet|--opus]
allowed-tools: [Read, Task, Bash(ls:*), Bash(mv:*), Bash(git:*), Bash(find:*), Bash(mkdir:*), Glob]
---

<context>
Git status: !`git status --short`
</context>

<objective>
Execute one or more prompts as delegated sub-tasks with fresh context. Supports single prompt execution, parallel execution of multiple independent prompts, and sequential execution of dependent prompts.

Prompts are stored at the **git root** of their target project: `{git_root}/prompts/`
</objective>

<prompt_discovery>
**Finding prompts - resolution order:**

1. **Absolute/relative path given** (e.g., `~/Documents/workspaces/trading/prompts/005`):
   - Use directly
2. **Number given** (e.g., "005", "5"):
   - Check `./prompts/` relative to CWD (works when CWD is the git repo, e.g., in Docker)
   - If not found, find git root of CWD: `git rev-parse --show-toplevel` → check `{git_root}/prompts/`
   - If still not found, scan all workspaces: `find ~/Documents/workspaces -maxdepth 2 -type d -name prompts 2>/dev/null`
   - Search each found prompts dir for matching number
   - If multiple matches across repos → list and ask user to pick
3. **Partial name given** (e.g., "retry", "notification"):
   - Same search order as above, match against filename
4. **Empty/no arguments**:
   - Same search order, pick most recently modified prompt file
</prompt_discovery>

<input>
The user will specify which prompt(s) to run via $ARGUMENTS, which can be:

**Single prompt:**

- Empty (no arguments): Run the most recently created prompt
- A prompt number (e.g., "001", "5", "42")
- A partial filename (e.g., "user-auth", "dashboard")
- A full path (e.g., "~/Documents/workspaces/trading/prompts/005")

**Multiple prompts:**

- Multiple numbers (e.g., "005 006 007")
- Multiple paths (e.g., ".../trading/prompts/005 .../trading/prompts/006")
- With execution flag: "005 006 007 --parallel" or "005 006 007 --sequential"
- If no flag specified with multiple prompts, default to --sequential for safety

**Model selection (optional):**

- `--haiku`: Run with haiku model (fast, cost-effective for simple tasks)
- `--sonnet`: Run with sonnet model (balanced for standard tasks)
- `--opus`: Run with opus model (thorough for complex tasks)
- If no model flag specified, inherits from parent context
</input>

<process>
<step1_parse_arguments>
Parse $ARGUMENTS to extract:
- Prompt numbers/names/paths (all arguments that are not flags)
- Execution strategy flag (--parallel or --sequential)
- Model flag (--haiku, --sonnet, or --opus)

<examples>
- "005" → Single prompt: 005, model: inherit from parent
- "005 --haiku" → Single prompt: 005, model: haiku
- "~/Documents/workspaces/trading/prompts/005" → Single prompt at absolute path
- "005 006 007" → Multiple prompts: [005, 006, 007], strategy: sequential (default), model: inherit
- "005 006 007 --parallel" → Multiple prompts: [005, 006, 007], strategy: parallel, model: inherit
- "005 006 007 --parallel --haiku" → Multiple prompts: [005, 006, 007], strategy: parallel, model: haiku
</examples>
</step1_parse_arguments>

<step2_resolve_files>
For each prompt number/name/path, follow the prompt_discovery resolution order above.

<matching_rules>

- If exactly one match found: Use that file
- If multiple matches found: List them and ask user to choose
- If no matches found: Report error and list available prompts across all known prompt directories
</matching_rules>

Once resolved, determine the git root for the prompt's project:
`git -C $(dirname $PROMPT_FILE) rev-parse --show-toplevel`

Store as `$PROJECT_ROOT` — this is where the sub-task should work.
</step2_resolve_files>

<step3_execute>
<single_prompt>

1. Read the complete contents of the prompt file
2. Delegate as sub-task using Task tool with subagent_type="general-purpose"
   - If model flag was specified (--haiku, --sonnet, --opus), pass model parameter to Task tool
   - If no model flag, omit model parameter (inherits from parent)
   - Include in the task prompt: "Working directory: $PROJECT_ROOT" so the agent works from git root
3. Wait for completion
4. Archive prompt to `$PROJECT_ROOT/prompts/completed/` with metadata
5. Return results
</single_prompt>

<parallel_execution>

1. Read all prompt files
2. **Spawn all Task tools in a SINGLE MESSAGE** (this is critical for parallel execution):
   - If model flag was specified, pass model parameter to each Task tool
   - If no model flag, omit model parameter (inherits from parent)
   - Include working directory in each task prompt
   <example>
   Use Task tool for prompt 005 (with model if specified)
   Use Task tool for prompt 006 (with model if specified)
   Use Task tool for prompt 007 (with model if specified)
   (All in one message with multiple tool calls)
   </example>
3. Wait for ALL to complete
4. Archive all prompts with metadata
5. Return consolidated results
</parallel_execution>

<sequential_execution>

1. Read first prompt file
2. Spawn Task tool for first prompt (with model parameter if specified)
3. Wait for completion
4. Archive first prompt
5. Read second prompt file
6. Spawn Task tool for second prompt (with model parameter if specified)
7. Wait for completion
8. Archive second prompt
9. Repeat for remaining prompts (using same model if specified)
10. Return consolidated results
</sequential_execution>
</step3_execute>
</process>

<context_strategy>
By delegating to a sub-task, the actual implementation work happens in fresh context while the main conversation stays lean for orchestration and iteration.
</context_strategy>

<output>
<single_prompt_output>
✓ Executed: $PROJECT_ROOT/prompts/005-implement-feature.md
✓ Project: $PROJECT_ROOT
✓ Model: haiku (or sonnet/opus if specified, or "inherited" if not specified)
✓ Archived to: $PROJECT_ROOT/prompts/completed/005-implement-feature.md

<results>
[Summary of what the sub-task accomplished]
</results>
</single_prompt_output>

<parallel_output>
✓ Executed in PARALLEL:

- $PROJECT_ROOT/prompts/005-implement-auth.md
- $PROJECT_ROOT/prompts/006-implement-api.md
- $PROJECT_ROOT/prompts/007-implement-ui.md

✓ All archived to $PROJECT_ROOT/prompts/completed/

<results>
[Consolidated summary of all sub-task results]
</results>
</parallel_output>

<sequential_output>
✓ Executed SEQUENTIALLY:

1. $PROJECT_ROOT/prompts/005-setup-database.md → Success
2. $PROJECT_ROOT/prompts/006-create-migrations.md → Success
3. $PROJECT_ROOT/prompts/007-seed-data.md → Success

✓ All archived to $PROJECT_ROOT/prompts/completed/

<results>
[Consolidated summary showing progression through each step]
</results>
</sequential_output>
</output>

<critical_notes>

- For parallel execution: ALL Task tool calls MUST be in a single message
- For sequential execution: Wait for each Task to complete before starting next
- Archive prompts only after successful completion
- If any prompt fails, stop sequential execution and report error
- Provide clear, consolidated results for multiple prompt execution
- Sub-tasks should always work from $PROJECT_ROOT (git root), not subdirectories
</critical_notes>
