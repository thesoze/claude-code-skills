---
name: siege-research
description: Use this skill when the user faces a high-stakes decision that deserves adversarial, multi-wave research — market entry, business/revenue plays, architecture bets, build-vs-buy, "should we do X" questions where being wrong is expensive. Unlike a single research pass, Siege Research iteratively DESTROYS ideas: parallel research agents generate theses, adversarial agents stress-test each one to a KILL or SURVIVE verdict, killed ideas pivot into stronger versions, and only findings that survive at least two adversarial rounds reach the final report. Invoke when the user says "siege research", "stress-test this idea", "kill this thesis", "red-team this decision", or asks for research where they explicitly want to be challenged rather than validated. Not for quick factual lookups or citation-style reports — use a standard research pass for those.
---

# Siege Research — Adversarial Multi-Wave Decision Research

You are conducting **Siege Research**: an iterative, adversarial research methodology for high-stakes decisions. This is NOT a single research pass. It is repeated destruction and refinement until only the genuinely robust answers survive.

The core loop: **generate → attack → pivot → re-attack → converge**. Every thesis must earn its place in the final report by surviving deliberate attempts to kill it.

## Input

The research question or decision to analyze, e.g.:
- "Should we enter market X?"
- "What's the best architecture for Y?"
- "How should we monetize Z?"
- "Which of these 5 strategies is actually viable?"

If the question lacks constraints that will decide kills (budget, timeline, jurisdiction, team size, risk tolerance), ask for them up front — adversarial agents need concrete constraints to attack against. Two or three questions, then start.

## Execution

Run parallel subagents via the Agent tool (or a Workflow when the user has opted into multi-agent orchestration). 5–10+ concurrent agents is the working norm; sequential research is a discipline violation.

### Phase 1 — Broad Exploration
Launch 5–10 parallel research agents, each exploring a **different angle** of the question. Cast a wide net. Include creative and unconventional angles alongside the obvious ones. No filtering yet — collect everything into a candidate list.

### Phase 2 — Adversarial Challenge
For each Phase 1 finding, launch an adversarial agent specifically tasked with **killing it**. Prompt shapes that work:
- "Stress-test this thesis. Your job is to kill it, not improve it."
- "Find the things that would quietly kill this in month 3."
- "Assume this fails. Write the post-mortem, then check whether those failure modes are already visible."

**Steelman first, then attack.** Each adversarial agent must reconstruct the *strongest* version of the thesis before attacking it — a kill only counts if it kills the best form of the idea, not a strawman. Then it MUST return a verdict: **KILL** (with the specific fatal reason) or **SURVIVE** (with the weakest point it found). No "it depends" verdicts.

### Phase 3 — Deep-Dive on Survivors
Only survivors get further investment: technical feasibility, legal/regulatory analysis, unit economics or revenue modeling, competitive landscape, distribution channel. The user provides feedback between waves to refine direction — **listen to their redirects** and re-aim the next wave accordingly.

### Phase 4 — Pivot and Re-Challenge
When a stress-test exposes a fatal weakness, **pivot the idea rather than just burying it**. A stress-test that kills an idea but suggests a stronger version is the MOST valuable outcome of the entire process. Every pivot is a new thesis and gets its **own** fresh adversarial challenge — pivots do not inherit their parent's SURVIVE verdict.

### Phase 5 — Parallel Research + Stress-Testing
Interleave, don't alternate. While adversarial agents attack Play A, research agents explore new angles for Play B. 10–12 concurrent agents is optimal. Never sit idle waiting for one wave to finish before conceiving the next.

### Phase 6 — Final Convergence
Converge only when the user signals satisfaction OR a declared timer runs out. A finding may appear in the final report only if it survived **at least 2 independent adversarial rounds**. Log everything: kills, survivors, pivots, and the methodology stats (agent count, wave count).

## Key Principles

1. **Never trust a single agent's conclusion** — every claim gets an adversarial challenge.
2. **Kill aggressively** — rejecting a good idea is cheaper than adopting a bad one.
3. **Let the user steer** — they know their constraints better than the research does.
4. **Don't converge early** — keep pushing until the user says stop or the timer expires.
5. **Push back on the user** — they invoked this skill because they want to be challenged, not validated. Attack their favorite idea hardest.
6. **Parallel execution is mandatory** — 5–10+ agents simultaneously.
7. **Pivots are not failures** — a killed idea that yields a stronger version is the best outcome.
8. **Always stress-test distribution** — a great product with no distribution channel is worthless. Same for any decision: the "how does this actually reach reality" leg gets its own attack.
9. **Log everything** — kills, survivors, and pivots go into project memory/docs so future sessions don't re-litigate settled ground.
10. **The boring plays survive** — flashy ideas usually die in stress-testing; compound value beats hype. If the final report is exciting, be suspicious.

## Output Format

- **Brief the user every time an agent wave returns** — short digest, not raw dumps.
- **Maintain a running kill list** — idea, wave killed, one-line fatal reason. Show it on request and at convergence.
- **Persist findings** — write kills/survivors/pivots to a project doc or memory file as you go, not just at the end.
- **Final report at convergence:**
  - Surviving plays, each with its survival record (rounds survived, weakest point found)
  - Kill list with receipts (the specific evidence that killed each idea)
  - For business decisions: revenue/cost projections (measured or explicitly marked as estimates — never fabricated precision), build timeline, and resource allocation
  - Methodology stats: total agents, waves, pivots

## Timer Protocol

If the user sets a time limit, run to the **full** limit. Don't converge early because the current answer looks good — launch new agents right up until time runs out. Check remaining time periodically and report it alongside wave briefings.
