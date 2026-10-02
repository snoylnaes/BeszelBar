# BeszelBar

So here's the deal, I wanted Beszel but smaller and the original [BeszelBar](https://github.com/Loriage/BeszelBar) did all the hard part.

I took away much of the live view in lieu of proper charts.

# Screenshot

<img width="1384" height="1984" alt="image" src="https://github.com/user-attachments/assets/d487ac7f-808f-4bb8-bc6a-d5a4ba6a0491" />

# Additions

- Little tiny baby Beszel charts in the correct Beszel colors on Beszel-style cards (with hover!)
- Settings to add/remove specific charts per system (CPU, storage, networking are currently available)
- Chart renaming
- System reordering
- System hiding

# Subtractions

- Usage bar was replaced by the charts
- Percentage was replaced by the charts
- Copy host button is gone

# Other changes

- Color palette changes and additions
- Docker view is completely in the submenu now
- Most menu items/buttons have been replaced with icons in headers
- Replaced "BeszelBar" in the header (sorry) with currently selected hub, status icons go below that
- Refresh logic was dialed in slightly differently (should be imperceptible)

# Todo

- Instead of one menubar icon for the hub, I want an option for one menubar icon per system that goes straight to the main system view. 
- Add support for the rest of the chart types
- Remove the "now" values, Beszel is charts, I can look at the charts
- Change time frames for charts

## Acknowledgements

[Loriage](https://github.com/Loriage) made BeszelBar. 

## License

MIT License — see [LICENSE](LICENSE) for details.
