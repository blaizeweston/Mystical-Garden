extends RefCounted
const Warden = preload("res://warden_tree.gd")
const Subclasses = preload("res://subclass_catalog.gd")
const Weaver = preload("res://weaver_connected_tree.gd")
const ConnectedTree = preload("res://connected_class_tree.gd")
const DEFINITIONS := [
 {
  "id": "warden",
  "name": "Warden",
  "skill": "Guard",
  "mode": "guard",
  "skill_cooldown": 4800,
  "description": "Hold ground with living wood.",
  "weapons": [
   {
    "id": "0_0",
    "name": "Rootblade",
    "reach": 2.25,
    "strike_ms": 450,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 1,
    "pattern": "single",
    "visual": "blade"
   },
   {
    "id": "0_1",
    "name": "Briar Spear",
    "reach": 3.1,
    "strike_ms": 650,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 2,
    "pattern": "line",
    "visual": "spear"
   },
   {
    "id": "0_2",
    "name": "Heartwood Maul",
    "reach": 2.1,
    "strike_ms": 950,
    "damage": 2,
    "roll_spread_hp": 3,
    "targets": 3,
    "pattern": "sweep",
    "visual": "hammer"
   }
  ],
  "nodes": [
   {
    "id": "0",
    "name": "Deepened Guard",
    "level": 2,
    "tier": 0,
    "effects": {
     "max_health": 2
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "augment"
    }
   },
   {
    "id": "1",
    "name": "Living Bastion",
    "level": 2,
    "tier": 0,
    "effects": {
     "reach": 0.35
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "replace"
    }
   },
   {
    "id": "2",
    "name": "Deepened Root Quake",
    "level": 3,
    "tier": 1,
    "effects": {
     "skill_duration": 550
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "augment"
    }
   },
   {
    "id": "3",
    "name": "Briar Charge",
    "level": 3,
    "tier": 1,
    "effects": {
     "stagger": 70
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "replace"
    }
   },
   {
    "id": "4",
    "name": "Guard Tempering",
    "level": 4,
    "tier": 2,
    "effects": {
     "targets": 1
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "master"
    }
   },
   {
    "id": "5",
    "name": "Quake Resonance",
    "level": 4,
    "tier": 2,
    "effects": {
     "cooldown": 70
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "master"
    }
   },
   {
    "id": "6",
    "name": "Living Rhythm",
    "level": 5,
    "tier": 3,
    "effects": {
     "damage": 1
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "efficient"
    }
   },
   {
    "id": "7",
    "name": "Primal Flourish",
    "level": 5,
    "tier": 3,
    "effects": {
     "graft_chance": 0.1
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "power"
    }
   },
   {
    "id": "8",
    "name": "Bastion: Rootshield",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "directional_guard": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Rootshield",
      "mode": "front_guard",
      "cooldown": 8500,
      "duration": 2200,
      "charges": 3,
      "radius": 3.0,
      "description": "Hold a directional root shield. Allies in front receive guard. Move at 40% speed while holding it."
     }
    }
   },
   {
    "id": "9",
    "name": "Vanguard: Thorn Counter",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "counter_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Thorn Counter",
      "mode": "counter_guard",
      "cooldown": 6800,
      "duration": 1600,
      "charges": 2,
      "description": "Block an attack to strengthen your next weapon hit."
     }
    }
   },
   {
    "id": "10",
    "name": "Sanctuary of Bark",
    "level": 7,
    "tier": 5,
    "parents": [
     "8"
    ],
    "effects": {
     "ward_on_block": 1,
     "shatter_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Sanctuary Quake",
      "mode": "quake",
      "cooldown": 8500,
      "damage": 2,
      "radius": 3.5,
      "field": "tide",
      "field_duration": 2400,
      "field_power": 0,
      "field_ward": true,
      "description": "Quake the earth and create a stationary warding circle. Living allies inside are briefly guarded; fallen allies remain fallen."
     }
    }
   },
   {
    "id": "11",
    "name": "Shattering Advance",
    "level": 7,
    "tier": 5,
    "parents": [
     "9"
    ],
    "effects": {
     "counter_stagger": 200,
     "shatter_damage": 2
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Shattering Advance",
      "mode": "charge",
      "cooldown": 7500,
      "damage": 3,
      "radius": 2.5,
      "travel": 3.5,
      "description": "Charge forward. Hits can trigger counter and brittle bonuses."
     }
    }
   }
  ],
  "skills": {
   "base": [
    {
     "name": "Guard",
     "mode": "guard",
     "cooldown": 4800,
     "description": "Raise a timed guard against incoming attacks.",
     "duration": 1150,
     "charges": 1,
     "color": "#c5ba79"
    },
    {
     "name": "Root Quake",
     "mode": "quake",
     "cooldown": 6500,
     "description": "Shake nearby roots, damaging and staggering foes.",
     "damage": 2,
     "radius": 3.0,
     "stagger": 300,
     "push": 0.8,
     "color": "#c8a96d"
    }
   ],
   "replace": [
    {
     "name": "Living Bastion",
     "mode": "bastion",
     "cooldown": 7200,
     "description": "Protect nearby allies with a layered guard.",
     "duration": 1800,
     "charges": 2,
     "radius": 3.5,
     "color": "#d9cc8c"
    },
    {
     "name": "Briar Charge",
     "mode": "charge",
     "cooldown": 7200,
     "description": "Rush safely forward and batter nearby enemies.",
     "damage": 2,
     "radius": 2.0,
     "travel": 3.5,
     "stagger": 250,
     "push": 1.0,
     "color": "#b8be79"
    }
   ]
  },
  "specializations": [
   "Living Bastion",
   "Thorn Vanguard"
  ]
 },
 {
  "id": "weaver",
  "name": "Weaver",
  "skill": "Rootbind",
  "mode": "bind",
  "skill_cooldown": 6000,
  "description": "Bind and reshape the corruption.",
  "weapons": [
   {
    "id": "1_0",
    "name": "Spore Staff",
    "reach": 4.0,
    "strike_ms": 720,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 1,
    "pattern": "single",
    "visual": "staff"
   },
   {
    "id": "1_1",
    "name": "Thorn Wand",
    "reach": 3.3,
    "strike_ms": 480,
    "damage": 1,
    "roll_spread_hp": 1,
    "targets": 1,
    "pattern": "single",
    "visual": "wand"
   },
   {
    "id": "1_2",
    "name": "Seed Focus",
    "reach": 3.4,
    "strike_ms": 950,
    "damage": 1,
    "roll_spread_hp": 3,
    "targets": 3,
    "pattern": "splash",
    "visual": "orb"
   }
  ],
  "nodes": [
   {
    "id": "0",
    "name": "Deepened Rootbind",
    "level": 2,
    "tier": 0,
    "effects": {
     "skill_duration": 650
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "augment"
    }
   },
   {
    "id": "1",
    "name": "Strangling Bloom",
    "level": 2,
    "tier": 0,
    "effects": {
     "reach": 0.6
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "replace"
    }
   },
   {
    "id": "2",
    "name": "Deepened Spore Nova",
    "level": 3,
    "tier": 1,
    "effects": {
     "skill_cooldown": 900
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "augment"
    }
   },
   {
    "id": "3",
    "name": "Mycelial Snare",
    "level": 3,
    "tier": 1,
    "effects": {
     "targets": 1
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "replace"
    }
   },
   {
    "id": "4",
    "name": "Rootbinder Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "windup_damage": 1
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "master"
    }
   },
   {
    "id": "5",
    "name": "Bloomcaller Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "recovery": 350
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "master"
    }
   },
   {
    "id": "6",
    "name": "Living Rhythm",
    "level": 5,
    "tier": 3,
    "effects": {
     "damage": 1
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "efficient"
    }
   },
   {
    "id": "7",
    "name": "Primal Flourish",
    "level": 5,
    "tier": 3,
    "effects": {
     "skill_cooldown": 1200
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "power"
    }
   },
   {
    "id": "8",
    "name": "Rootbinder: Interwoven Bind",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "spread_bind": 1,
     "mark_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Interwoven Bind",
      "mode": "bind",
      "cooldown": 7600,
      "range": 4.5,
      "bind": 1600,
      "damage": 1,
      "description": "Bind a target and a nearby foe. Follow-up contacts exploit marked enemies."
     }
    }
   },
   {
    "id": "9",
    "name": "Bloomcaller: Cultivate Bloom",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "growth_field": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Cultivate Bloom",
      "mode": "growth",
      "cooldown": 8000,
      "range": 4.5,
      "radius": 2.1,
      "field": "growth",
      "field_duration": 3200,
      "field_power": 1,
      "description": "Grow a stationary bloom at the target or at your feet. It pulses against foes in sight."
     }
    }
   },
   {
    "id": "10",
    "name": "Entangling Chorus",
    "level": 7,
    "tier": 5,
    "parents": [
     "8"
    ],
    "effects": {
     "spread_bind": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Entangling Chorus",
      "mode": "snare_field",
      "cooldown": 8500,
      "range": 4.5,
      "radius": 3.2,
      "bind": 1500,
      "damage": 2,
      "description": "Restrain a cluster; linked roots reach one more nearby enemy."
     }
    }
   },
   {
    "id": "11",
    "name": "Bloom Detonation",
    "level": 7,
    "tier": 5,
    "parents": [
     "9"
    ],
    "effects": {
     "growth_field": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Bloom Detonation",
      "mode": "bloom_detonate",
      "cooldown": 7500,
      "radius": 3.2,
      "damage": 4,
      "description": "Consume your cultivated bloom to strike enemies around it. Cultivate a bloom first."
     }
    }
   }
  ],
  "skills": {
   "base": [
    {
     "name": "Rootbind",
     "mode": "bind",
     "cooldown": 6000,
     "description": "Root a visible foe; it can still attack nearby players.",
     "duration": 1650,
     "range": 5.0,
     "color": "#a5c1a1"
    },
    {
     "name": "Spore Nova",
     "mode": "nova",
     "cooldown": 7000,
     "description": "Burst with spores that damage and briefly root nearby foes.",
     "damage": 1,
     "radius": 3.2,
     "bind": 600,
     "recovery": 250,
     "color": "#c2a1ce"
    }
   ],
   "replace": [
    {
     "name": "Strangling Bloom",
     "mode": "strangle",
     "cooldown": 7500,
     "description": "Damage and root a visible enemy for longer.",
     "damage": 2,
     "duration": 2200,
     "range": 5.5,
     "color": "#b5a1d2"
    },
    {
     "name": "Mycelial Snare",
     "mode": "snare_field",
     "cooldown": 8500,
     "description": "Plant a lingering snare that roots enemies entering it.",
     "radius": 2.5,
     "range": 6.0,
     "bind": 1800,
     "recovery": 600,
     "color": "#a3d0be"
    }
   ]
  },
  "specializations": [
   "Rootbinder",
   "Bloomcaller"
  ]
 },
 {
  "id": "ranger",
  "name": "Ranger",
  "skill": "Gale Volley",
  "mode": "volley",
  "skill_cooldown": 6500,
  "description": "Control distance and pierce the Wilds.",
  "weapons": [
   {
    "id": "2_0",
    "name": "Vine Bow",
    "reach": 6.0,
    "strike_ms": 850,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 1,
    "pattern": "line",
    "visual": "bow"
   },
   {
    "id": "2_1",
    "name": "Bark Arbalest",
    "reach": 4.8,
    "strike_ms": 1150,
    "damage": 2,
    "roll_spread_hp": 4,
    "targets": 2,
    "pattern": "line",
    "visual": "crossbow"
   },
   {
    "id": "2_2",
    "name": "Thorn Ring",
    "reach": 3.6,
    "strike_ms": 700,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 2,
    "pattern": "chain",
    "visual": "ring"
   }
  ],
  "nodes": [
   {
    "id": "0",
    "name": "Deepened Gale Volley",
    "level": 2,
    "tier": 0,
    "effects": {
     "reach": 0.8
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "augment"
    }
   },
   {
    "id": "1",
    "name": "Piercing Salvo",
    "level": 2,
    "tier": 0,
    "effects": {
     "cooldown": 70
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "replace"
    }
   },
   {
    "id": "2",
    "name": "Deepened Bramble Snare",
    "level": 3,
    "tier": 1,
    "effects": {
     "dodge_cooldown": 180
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "augment"
    }
   },
   {
    "id": "3",
    "name": "Windstep",
    "level": 3,
    "tier": 1,
    "effects": {
     "windup_damage": 1
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "replace"
    }
   },
   {
    "id": "4",
    "name": "Wildstalker Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "targets": 1
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "master"
    }
   },
   {
    "id": "5",
    "name": "Snarekeeper Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "skill_cooldown": 1000
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "master"
    }
   },
   {
    "id": "6",
    "name": "Living Rhythm",
    "level": 5,
    "tier": 3,
    "effects": {
     "damage": 1
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "efficient"
    }
   },
   {
    "id": "7",
    "name": "Primal Flourish",
    "level": 5,
    "tier": 3,
    "effects": {
     "knockback": 0.6
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "power"
    }
   },
   {
    "id": "8",
    "name": "Wildstalker: Hunter’s Salvo",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "precision": 1,
     "mark_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Hunter’s Salvo",
      "mode": "salvo",
      "cooldown": 7200,
      "range": 7.0,
      "width": 0.65,
      "targets": 3,
      "damage": 3,
      "description": "A narrow piercing salvo marks enemies. Repeated precision contact punishes marked foes."
     }
    }
   },
   {
    "id": "9",
    "name": "Snarekeeper: Luring Shot",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "decoy": 1,
     "trap_power": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Luring Shot",
      "mode": "salvo",
      "cooldown": 7600,
      "range": 6.0,
      "width": 0.7,
      "targets": 2,
      "damage": 1,
      "description": "A low-damage shot prepares a temporary lure, drawing pursuing foes into your trap lanes."
     }
    }
   },
   {
    "id": "10",
    "name": "Stalker’s Retreat",
    "level": 7,
    "tier": 5,
    "parents": [
     "8"
    ],
    "effects": {
     "veil_mark": 1,
     "mark_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Stalker’s Retreat",
      "mode": "windstep",
      "cooldown": 7500,
      "travel": 3.5,
      "duration": 2000,
      "description": "Retreat. Your next weapon hit marks its target."
     }
    }
   },
   {
    "id": "11",
    "name": "Thorn Lattice",
    "level": 7,
    "tier": 5,
    "parents": [
     "9"
    ],
    "effects": {
     "trap_power": 1,
     "spread_bind": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Thorn Lattice",
      "mode": "snare_field",
      "cooldown": 8800,
      "range": 6.0,
      "radius": 3.0,
      "bind": 1300,
      "damage": 1,
      "field": "growth",
      "field_duration": 2200,
      "field_power": 1,
      "description": "Bind a cluster inside a prepared, damaging root lattice. Lures help funnel enemies toward it."
     }
    }
   }
  ],
  "skills": {
   "base": [
    {
     "name": "Gale Volley",
     "mode": "volley",
     "cooldown": 6500,
     "description": "Fire an empowered attack and gain brief faster, broader attacks.",
     "duration": 1200,
     "color": "#b7d6be"
    },
    {
     "name": "Bramble Snare",
     "mode": "snare",
     "cooldown": 6500,
     "description": "Set a bramble trap that strikes and roots enemies entering it.",
     "damage": 1,
     "range": 6.5,
     "bind": 1300,
     "radius": 1.05,
     "color": "#9cc194"
    }
   ],
   "replace": [
    {
     "name": "Piercing Salvo",
     "mode": "salvo",
     "cooldown": 8000,
     "description": "Send a powerful piercing line through several visible enemies.",
     "damage": 3,
     "range": 8.0,
     "width": 1.0,
     "targets": 4,
     "color": "#d4d7a0"
    },
    {
     "name": "Windstep",
     "mode": "windstep",
     "cooldown": 5500,
     "description": "Step away safely and gain Gale Focus.",
     "travel": 3.0,
     "duration": 1900,
     "color": "#c0dfd0"
    }
   ]
  },
  "specializations": [
   "Wildstalker",
   "Snarekeeper"
  ]
 },
 {
  "id": "reaper",
  "name": "Reaper",
  "skill": "Reaping Step",
  "mode": "reap",
  "skill_cooldown": 5500,
  "description": "Close quickly and harvest openings.",
  "weapons": [
   {
    "id": "3_0",
    "name": "Graft Knives",
    "reach": 1.7,
    "strike_ms": 320,
    "damage": 1,
    "roll_spread_hp": 1,
    "targets": 1,
    "pattern": "single",
    "visual": "knives"
   },
   {
    "id": "3_1",
    "name": "Harvest Scythe",
    "reach": 2.7,
    "strike_ms": 900,
    "damage": 1,
    "roll_spread_hp": 3,
    "targets": 3,
    "pattern": "sweep",
    "visual": "scythe"
   },
   {
    "id": "3_2",
    "name": "Root Lash",
    "reach": 3.4,
    "strike_ms": 720,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 2,
    "pattern": "line",
    "visual": "whip"
   }
  ],
  "nodes": [
   {
    "id": "0",
    "name": "Deepened Reaping Step",
    "level": 2,
    "tier": 0,
    "effects": {
     "heal_on_kill": 1
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "augment"
    }
   },
   {
    "id": "1",
    "name": "Shadow Harvest",
    "level": 2,
    "tier": 0,
    "effects": {
     "damage": 1
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "replace"
    }
   },
   {
    "id": "2",
    "name": "Deepened Siphon Cut",
    "level": 3,
    "tier": 1,
    "effects": {
     "dodge_cooldown": 180
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "augment"
    }
   },
   {
    "id": "3",
    "name": "Blood Moon",
    "level": 3,
    "tier": 1,
    "effects": {
     "reach": 0.45
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "replace"
    }
   },
   {
    "id": "4",
    "name": "Blood Harvester Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "pull": 0.5
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "master"
    }
   },
   {
    "id": "5",
    "name": "Veilwalker Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "cooldown": 70
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "master"
    }
   },
   {
    "id": "6",
    "name": "Living Rhythm",
    "level": 5,
    "tier": 3,
    "effects": {
     "windup_damage": 2
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "efficient"
    }
   },
   {
    "id": "7",
    "name": "Primal Flourish",
    "level": 5,
    "tier": 3,
    "effects": {
     "skill_heal": 1
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "power"
    }
   },
   {
    "id": "8",
    "name": "Blood Harvester: Harvest Frenzy",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "death_charge": 1,
     "reaper_momentum": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Harvest Frenzy",
      "mode": "reap",
      "cooldown": 6500,
      "travel": 2.5,
      "duration": 1200,
      "radius": 2.2,
      "description": "Close the distance. Kills store death charges that strengthen later hits."
     }
    }
   },
   {
    "id": "9",
    "name": "Veilwalker: Veil Passage",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "veil_mark": 1,
     "mark_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Veil Passage",
      "mode": "harvest",
      "cooldown": 7000,
      "range": 5.0,
      "travel": 3.2,
      "duration": 1000,
      "radius": 2.5,
      "damage": 2,
      "description": "Slip toward a target through a safe route, strike nearby foes and prepare your next mark."
     }
    }
   },
   {
    "id": "10",
    "name": "Feast of Thorns",
    "level": 7,
    "tier": 5,
    "parents": [
     "8"
    ],
    "effects": {
     "death_charge": 1,
     "heal_on_kill": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Feast of Thorns",
      "mode": "bloodmoon",
      "cooldown": 8500,
      "radius": 3.0,
      "damage": 3,
      "heal": 1,
      "description": "Drain nearby foes. Successful aggression sustains you and replenishes death charges."
     }
    }
   },
   {
    "id": "11",
    "name": "Delayed Requiem",
    "level": 7,
    "tier": 5,
    "parents": [
     "9"
    ],
    "effects": {
     "mark_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Delayed Requiem",
      "mode": "requiem",
      "cooldown": 8500,
      "range": 5.0,
      "radius": 2.5,
      "damage": 3,
      "delay": 700,
      "description": "Mark a cluster for a delayed strike. The strike requires clear sight when it resolves."
     }
    }
   }
  ],
  "skills": {
   "base": [
    {
     "name": "Reaping Step",
     "mode": "reap",
     "cooldown": 5500,
     "description": "Close safely, make an empowered strike and briefly guard.",
     "travel": 3.0,
     "duration": 350,
     "color": "#beabbc"
    },
    {
     "name": "Siphon Cut",
     "mode": "siphon",
     "cooldown": 6500,
     "description": "Cut a nearby foe and restore health when it connects.",
     "damage": 2,
     "range": 3.0,
     "heal": 1,
     "color": "#ca8797"
    }
   ],
   "replace": [
    {
     "name": "Shadow Harvest",
     "mode": "harvest",
     "cooldown": 7500,
     "description": "Rush into a cluster and harvest enemies around the landing.",
     "travel": 4.0,
     "range": 7.0,
     "radius": 2.2,
     "damage": 3,
     "duration": 450,
     "color": "#b798cd"
    },
    {
     "name": "Blood Moon",
     "mode": "bloodmoon",
     "cooldown": 9000,
     "description": "Damage nearby enemies and drain health from those hit.",
     "damage": 2,
     "radius": 3.0,
     "heal": 1,
     "recovery": 400,
     "color": "#cf849f"
    }
   ]
  },
  "specializations": [
   "Blood Harvester",
   "Veilwalker"
  ]
 },
 {
  "id": "oracle",
  "name": "Oracle",
  "skill": "Renewal",
  "mode": "heal",
  "skill_cooldown": 8000,
  "description": "Sustain the party through living rituals.",
  "weapons": [
   {
    "id": "4_0",
    "name": "Bloom Bell",
    "reach": 2.7,
    "strike_ms": 850,
    "damage": 1,
    "roll_spread_hp": 2,
    "targets": 2,
    "pattern": "splash",
    "visual": "bell"
   },
   {
    "id": "4_1",
    "name": "Spore Censer",
    "reach": 3.2,
    "strike_ms": 1050,
    "damage": 1,
    "roll_spread_hp": 3,
    "targets": 3,
    "pattern": "sweep",
    "visual": "censer"
   },
   {
    "id": "4_2",
    "name": "Petal Fan",
    "reach": 3.6,
    "strike_ms": 700,
    "damage": 1,
    "roll_spread_hp": 1,
    "targets": 2,
    "pattern": "sweep",
    "visual": "fan"
   }
  ],
  "nodes": [
   {
    "id": "0",
    "name": "Deepened Renewal",
    "level": 2,
    "tier": 0,
    "effects": {
     "max_health": 2
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "augment"
    }
   },
   {
    "id": "1",
    "name": "Sanctuary",
    "level": 2,
    "tier": 0,
    "effects": {
     "skill_heal": 1
    },
    "parents": [],
    "skill_change": {
     "slot": 0,
     "kind": "replace"
    }
   },
   {
    "id": "2",
    "name": "Deepened Warding Chime",
    "level": 3,
    "tier": 1,
    "effects": {
     "graft_chance": 0.08
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "augment"
    }
   },
   {
    "id": "3",
    "name": "Judgement Bell",
    "level": 3,
    "tier": 1,
    "effects": {
     "familiarity": 1
    },
    "parents": [
     "0",
     "1"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "replace"
    }
   },
   {
    "id": "4",
    "name": "Lifekeeper Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "recovery": 400
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "master"
    }
   },
   {
    "id": "5",
    "name": "Omenreader Discipline",
    "level": 4,
    "tier": 2,
    "effects": {
     "skill_cooldown": 1000
    },
    "parents": [
     "2",
     "3"
    ],
    "skill_change": {
     "slot": 1,
     "kind": "master"
    }
   },
   {
    "id": "6",
    "name": "Living Rhythm",
    "level": 5,
    "tier": 3,
    "effects": {
     "skill_heal": 2
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "efficient"
    }
   },
   {
    "id": "7",
    "name": "Primal Flourish",
    "level": 5,
    "tier": 3,
    "effects": {
     "targets": 1,
     "knockback": 0.3
    },
    "parents": [
     "4",
     "5"
    ],
    "skill_change": {
     "slot": 0,
     "kind": "power"
    }
   },
   {
    "id": "8",
    "name": "Lifekeeper: Living Sanctuary",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "protect_growth": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Living Sanctuary",
      "mode": "sanctuary",
      "cooldown": 10000,
      "heal": 1,
      "radius": 4.0,
      "duration": 3500,
      "charges": 1,
      "ward_duration": 1000,
      "field": "tide",
      "field_duration": 3000,
      "field_power": 1,
      "field_ward": true,
      "description": "Heal and shelter living allies inside a stationary sanctuary. Position it where allies can safely remain."
     }
    }
   },
   {
    "id": "9",
    "name": "Omenreader: Foretell",
    "level": 6,
    "tier": 4,
    "parents": [
     "6",
     "7"
    ],
    "effects": {
     "omen": 1,
     "mark_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 0,
     "values": {
      "name": "Foretell",
      "mode": "judgement",
      "cooldown": 7800,
      "damage": 1,
      "range": 6.0,
      "radius": 2.4,
      "description": "Mark a distant cluster. Later contacts punish marked enemies during their wind-up."
     }
    }
   },
   {
    "id": "10",
    "name": "Cleansing Bower",
    "level": 7,
    "tier": 5,
    "parents": [
     "8"
    ],
    "effects": {
     "pool_ward": 1,
     "skill_heal": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Cleansing Bower",
      "mode": "sanctuary",
      "cooldown": 9500,
      "heal": 1,
      "radius": 4.0,
      "duration": 2800,
      "charges": 1,
      "ward_duration": 1000,
      "field": "tide",
      "field_duration": 2400,
      "field_power": 0,
      "field_ward": true,
      "cleanse": true,
      "description": "Cleanse slowing roots and ward nearby living allies. Fallen allies require a separate revival."
     }
    }
   },
   {
    "id": "11",
    "name": "Sentence of Dawn",
    "level": 7,
    "tier": 5,
    "parents": [
     "9"
    ],
    "effects": {
     "omen": 1,
     "shatter_damage": 1
    },
    "skill_change": {
     "kind": "modify",
     "slot": 1,
     "values": {
      "name": "Sentence of Dawn",
      "mode": "judgement",
      "cooldown": 8500,
      "damage": 3,
      "range": 6.0,
      "radius": 3.0,
      "recovery": 500,
      "description": "Punish a marked cluster as it commits to an attack, extending enemy recovery."
     }
    }
   }
  ],
  "skills": {
   "base": [
    {
     "name": "Renewal",
     "mode": "heal",
     "cooldown": 8000,
     "description": "Heal nearby allies, then grant brief regrowth.",
     "heal": 2,
     "radius": 4.0,
     "duration": 2000,
     "color": "#c4d8a0"
    },
    {
     "name": "Warding Chime",
     "mode": "ward",
     "cooldown": 7000,
     "description": "Guard nearby allies against one incoming attack.",
     "radius": 4.0,
     "duration": 1500,
     "charges": 1,
     "color": "#e6d59c"
    }
   ],
   "replace": [
    {
     "name": "Sanctuary",
     "mode": "sanctuary",
     "cooldown": 10000,
     "description": "Grant allies longer regrowth and a brief protective ward.",
     "heal": 1,
     "radius": 4.5,
     "duration": 4500,
     "charges": 1,
     "ward_duration": 800,
     "color": "#dfd4a6"
    },
    {
     "name": "Judgement Bell",
     "mode": "judgement",
     "cooldown": 8500,
     "description": "Strike a distant cluster and prolong enemy recovery.",
     "damage": 2,
     "range": 6.0,
     "radius": 2.8,
     "recovery": 700,
     "color": "#e3c195"
    }
   ]
  },
  "specializations": [
   "Lifekeeper",
   "Omenreader"
  ]
 }
]
static var FRAMES: Array = make_frames()
static func make_frames() -> Array:
 var result: Array=[]
 for entry in DEFINITIONS:
  var weapon: Dictionary=entry.weapons[0]
  result.append({"name":entry.name,"weapon":weapon.name,"reach":weapon.reach,"strike_ms":weapon.strike_ms,"skill":entry.skills.base[0].name,"skill_cooldown":entry.skills.base[0].cooldown})
 return result

static func count_bits(value: int) -> int:
 var total := 0
 for i in 63:
  total += (value >> i) & 1
 return total

static func bonuses(profile: Dictionary, class_id: int) -> Dictionary:
 var result := {}
 var learned: Array = profile.get("upgrades", [0,0,0,0,0])
 var mask: int = int(learned[class_id]) if class_id<learned.size() else 0
 for i in DEFINITIONS[class_id].nodes.size():
  if mask & (1 << i):
   for key in DEFINITIONS[class_id].nodes[i].effects:
    result[key] = float(result.get(key,0)) + float(DEFINITIONS[class_id].nodes[i].effects[key])
 return result

static func connected_tree(class_id: int) -> ConnectedTree:
 match class_id:
  0: return Warden.Connected.TREE
  1: return Weaver.TREE
 return null


static func connected_in_world(game: Node, class_id: int, profile: Dictionary) -> ConnectedTree:
 var tree := connected_tree(class_id)
 return tree if tree != null and game.has_meta(&"combat_affinity_ruleset") and tree.eligible(profile) else null


static func branch_nodes(class_id: int) -> Array:
 return Warden.NODES if class_id==0 else Subclasses.NODES[class_id-1]

static func focus_id(profile: Dictionary,class_id: int) -> String:
 return Warden.focus(profile) if class_id==0 else Subclasses.focus(profile,class_id).get("id","")

static func focus_name(id: String) -> String:
 var warden_name:=Warden.focus_name(id)
 return Subclasses.focus_name(id) if warden_name.is_empty() else warden_name

static func all_nodes(class_id: int) -> Array:
 return DEFINITIONS[class_id].nodes + branch_nodes(class_id)

static func points(profile: Dictionary,class_id: int,level: int) -> int:
 return Warden.points(profile,level,class_id) if not Warden.legacy(profile,class_id) else maxi(0,level-1-count_bits(int(profile.upgrades[class_id])))

static func can_learn(profile: Dictionary,class_id: int,node_id: int,level: int) -> bool:
 if class_id<0 or class_id>=DEFINITIONS.size():return false
 if not Warden.legacy(profile,class_id):return Warden.can_learn(profile,node_id,level,class_id,branch_nodes(class_id))
 return can_learn_legacy(profile,class_id,node_id,level)

static func can_learn_legacy(profile: Dictionary,class_id: int,node_id: int,level: int) -> bool:
 if class_id<0 or class_id>=DEFINITIONS.size() or node_id<0 or node_id>=DEFINITIONS[class_id].nodes.size() or node_id>=63: return false
 var mask: int=profile.upgrades[class_id];var node: Dictionary=DEFINITIONS[class_id].nodes[node_id]
 if mask&(1<<node_id) or level<int(node.level) or count_bits(mask)>=level-1: return false
 var parents: Array=node.get("parents",[]);var parent_ok: bool=parents.is_empty()
 for i in DEFINITIONS[class_id].nodes.size():
  if not (mask&(1<<i)): continue
  var learned: Dictionary=DEFINITIONS[class_id].nodes[i]
  if int(learned.tier)==int(node.tier): return false
  if parents.has(learned.id): parent_ok=true
 return parent_ok

static func effect_text(values: Dictionary, show_hp: bool = false) -> String:
 var names := {"max_health":"health","reach":"reach (m)","cooldown":"faster strikes (ms)","targets":"extra targets","stagger":"hit stagger (ms)","skill_duration":"skill duration (ms)","skill_cooldown":"faster class skill (ms)","damage":"strike damage","windup_damage":"damage during enemy wind-up","graft_chance":"grafting chance","dodge_cooldown":"faster dodge (ms)","heal_on_kill":"health on killing strike","skill_heal":"class-skill healing","recovery":"enemy recovery (ms)","knockback":"knockback (m)","pull":"pull (m)","familiarity":"extra cultivation familiarity"}
 var lines: Array[String]=[]
 for key in values:
  if show_hp:
   var hp: String=preload("res://combat_balance_preview.gd").component_hp_text({key:values[key]})
   if not hp.is_empty():
    lines.append(hp);continue
  if preload("res://combat_traits.gd").KEYS.has(key):
   lines.append(preload("res://combat_traits.gd").describe({key:values[key]}));continue
  lines.append("+%d%% grafting chance"%roundi(float(values[key])*100) if key=="graft_chance" else "+%s %s" % [str(values[key]),str(names.get(key,key))])
 return "\n".join(lines)
