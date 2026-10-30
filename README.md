# Pebble

**Small records. Clear picture.**

Pebble is a proposed **offline-first expense and receipt tracker** for Android and iOS, built using Flutter. Quickly add an expense manually, or photograph a receipt and review the automatically detected fields before saving it.

> **Project status:** Product specification and screen mockups. The Flutter application has not been implemented yet.

## Design preview

[![Pebble Home screen](docs/mockups/home.svg)](docs/mockups/README.md)

Explore the full [five-screen mockup gallery](docs/mockups/README.md): Home, Add Expense, Scan Receipt, Expenses and Insights.

## Documentation

- [**Complete Product Design & Build Specification**](docs/Pebble_Design_and_Build_Specification.md)
- [**Visual mockups and design notes**](docs/mockups/README.md)

## Architecture baseline

| Concern | Proposed technology |
| --- | --- |
| Cross-platform UI | Flutter, Material 3 |
| State management | Riverpod |
| Navigation | go_router |
| Structured persistence | Drift + SQLite |
| Receipt images | Application-private file storage |
| Receipt OCR | On-device Google ML Kit text recognition |
| Data portability | CSV export; complete ZIP backup/restore |
| Cloud dependency | None for v1 |

The planned first milestone is manual expense capture and local persistence, followed by receipt scanning, data safety, and spending insights.

See the [requirements and milestone plan](docs/Pebble_Design_and_Build_Specification.md) before beginning implementation.
