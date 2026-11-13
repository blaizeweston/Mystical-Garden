# Wilds monster grafting

Press **E or G** beside a grafting altar to open the specialized fourth-slot workbench. Opening the menu consumes nothing. The left side shows the current weapon, its three plant slots, installed monster component and resolved attributes. The right side lists only carried monster trophies, their tags, the player's success chance and the resolved weapon after a successful graft.

Choose a component and press **Attempt graft** or **Attempt replacement**. Each attempt consumes exactly one selected carried monster part. Materials in Garden storage cannot be used remotely; pack them at the Wilds gate or find them during the expedition.

A successful graft installs the component. At a later altar, a successful replacement sacrifices the previous component and installs the new one. A failed replacement consumes the new component but preserves the installed one. The old component is never refunded to inventory. The same installed component cannot be installed again, and a newly installed graft cannot be replaced at that same encounter's altar. The three plant slots and already purchased expedition upgrades remain intact.

Altars now appear every **eight encounters**, down from every four: encounters 8, 16, 24 and so on. They remain available during combat and stay excluded from the Heart finale. Their discovered map icon and procedural placement continue to use the existing system. Grafting does not pause the Wilds. Moving away or returning to the Garden closes the menu.

The system reuses the weapon resolver and monster-part catalog, so adding a monster part automatically makes its carried component eligible for this menu and its preview. The host validates range, altar presence, component ownership, monster-only slot rules and replacement timing for every attempt.

Verification: focused tests cover altar frequency, E/G opening without spending, carried-only choices, chance and stat previews, exact item consumption, same-altar rejection, successful and failed later replacements, preserved slots/upgrades, out-of-range and invalid requests, and cleanup on Garden return. Shrine/map visibility, class weapons, checkpoint flow and full solo gameplay checks also passed. Initial, replacement and empty-inventory screens were rendered and reviewed.

The exported Windows build passed the focused grafting test, including replacement behavior and previews. The refreshed playable EXE launched successfully.
