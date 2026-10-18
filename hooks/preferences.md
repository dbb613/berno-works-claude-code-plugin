# Berno Works preferences

These are the user's standing instructions. They take precedence over skill defaults, including Superpowers.

## Default stack
- Backend: Python 3.15, FastAPI, Pydantic v2, PydanticAI, SQLAlchemy 2.x (async, typed `Mapped[...]`) on PostgreSQL, Alembic.
- Frontend: React + TypeScript, Tailwind CSS, shadcn/ui.
- Slide decks: Reveal.js.

## Python
- Target Python 3.15. Annotate every function, method and module-level value; aim for a clean strict type check.
- Use modern syntax: `X | None`, built-in generics, `type` aliases, PEP 695 generics, `match` where it reads better.
- Prefer dataclasses or Pydantic models over loose dicts. Favor readability: small functions, intention-revealing names, early returns, comments that explain why.

## Tooling
- uv for everything: `uv add` / `uv remove`, `uv run`, PEP 723 for one-off scripts. No pip, Poetry or requirements.txt.
- ruff for lint and format; ty (or pyright where the project uses it) for types; pytest for tests.

## Documentation
- Before writing against a library API, look up current docs with Context7, especially SQLAlchemy 2.x, Alembic, PydanticAI and Reveal.js.

## Superpowers workflow preferences
- (none yet)
