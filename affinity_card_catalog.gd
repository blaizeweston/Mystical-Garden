extends RefCounted
## EC01 authoring. Values are in HP or milliseconds and apply only at the named consumer.
const RARITIES := ["Common", "Uncommon", "Rare", "Epic"]
const REQUIREMENT_VERSION := 1
const PLAYTEST := {
	"offer_size": 3,
	"acquisition_limit": 12,
	"reroll_costs": [2, 4, 6],
	"rarity_curve": [
		[1, [78, 18, 3, 1]],
		[18, [64, 25, 8, 3]],
		[42, [52, 30, 13, 5]],
		[90, [42, 32, 18, 8]],
	],
}

const DEFINITIONS := {
	"rime_opening": {
		"title": "Sharpened Petals", "scope": "core", "policy": "stackable",
		"trigger": "Opening petal contact", "consumer": ["res://frost_combat.gd", "bloom_phase"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "frost"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "rime_bloom",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "opening_bonus_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Rime Bloom's opening petals deal +%s damage.",
		"detail": "Applies to each enemy hit by the opening petals. Closing petals and Brittle keep their usual effects.",
	},
	"ember_impact": {
		"title": "Emberfront", "scope": "core", "policy": "stackable",
		"trigger": "First Ember Wake contact per enemy", "consumer": ["res://fire_combat.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "fire"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "ember_wake",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "impact_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Ember Wake deals +%s damage on first contact with each enemy.",
		"detail": "The bonus belongs to the trail's first impact on each enemy. Burning ticks keep their usual damage.",
	},
	"dewfall_impact": {
		"title": "Driving Rain", "scope": "core", "policy": "stackable",
		"trigger": "Dewfall curtain enemy contact", "consumer": ["res://water_combat.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "water"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "dewfall",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "impact_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Dewfall deals +%s damage to each enemy its curtain hits.",
		"detail": "The bonus applies to enemy contact. Drenched and Slow cleansing keep their usual effects.",
	},
	"vital_bloom_time": {
		"title": "Lingering Blossom", "scope": "core", "policy": "stackable",
		"trigger": "Vital Bloom grant", "consumer": ["res://vital_combat.gd", "grant"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "vital"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "vital_bloom",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Vitality granted by Vital Bloom by %s seconds.",
		"detail": "Vitality's Max HP and regeneration values stay the same. Each benefit uses its strongest active source.",
	},
	"thorn_line_bleed": {
		"title": "Sawtooth Briars", "scope": "core", "policy": "stackable",
		"trigger": "Thorn Line contributes to shared Bleed", "consumer": ["res://thorn_affinity.gd", "grow"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "thorn"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "thorn_line",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "tick_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Equipping Thorn Line raises your personal Bleed tick-damage cap by %s.",
		"detail": "Core, Form and Catalyst add fractions of the same personal cap. Counts this acquired contribution once, while the matching Core is equipped. Tick interval, slow and lingering time stay the same.",
	},
	"ironbark_time": {
		"title": "Seasoned Ironbark", "scope": "core", "policy": "stackable",
		"trigger": "Ironbark armor grant", "consumer": ["res://wood_affinity.gd", "grant"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "wood"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "ironbark",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Ironbark's Bark Armor by %s seconds while it has capacity.",
		"detail": "Armor still ends when it is depleted. Absorption and armor capacity stay the same.",
	},
	"chain_spark_power": {
		"title": "Gathered Thunder", "scope": "core", "policy": "stackable",
		"trigger": "Chain Spark discharge on Core contact", "consumer": ["res://storm_affinity.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "storm"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "chain_spark",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "initial",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Chain Spark starts with +%s damage. Later jumps use the increased damage with normal falloff.",
		"detail": "Requires a valid first hit. The maximum number of jumps and their range stay the same.",
	},
	"phantom_stride_time": {
		"title": "Lingering Footfall", "scope": "core", "policy": "stackable",
		"trigger": "Phantom Step landing", "consumer": ["res://spirit_affinity.gd", "grant"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "spirit"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "phantom_step",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "duration_bonus_ms",
		"values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Phantom Step's Spiritstride by %s seconds.",
		"detail": "Granted after a successful step. Travel distance, speed bonus and trace duration stay the same.",
	},
	"gravity_collapse": {
		"title": "Crushing Center", "scope": "core", "policy": "stackable",
		"trigger": "Gravity Well collapse", "consumer": ["res://void_affinity.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "void"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "gravity_well",
		        "slot": "core"
		      }
		    }
		  ]
		}, "parameter": "collapse",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Gravity Well's collapse deals +%s damage to each enemy still inside.",
		"detail": "Applies to the single collapse following the gathering phase. Gathering strength stays the same.",
	},
	"burning_strikes_heat": {
		"title": "Hotter Embers", "scope": "form", "policy": "stackable",
		"trigger": "Burning Strikes weapon contact", "consumer": ["res://fire_combat.gd", "ignite"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "form",
		        "primary_affinity": "fire"
		      }
		    },
		    {
		      "capability": {
		        "producer": "form",
		        "id": "burning_strikes",
		        "slot": "form"
		      }
		    }
		  ]
		}, "parameter": "stack_bonus",
		"values": [1, 2, 3, 4], "unit": "stacks", "limit": 4,
		"description": "Burning Strikes applies %s additional shared Burning stacks.",
		"detail": "Each qualifying direct basic attack contact adds the acquired stack contribution. Burning uses one shared tick/decay cadence; damage per stack and lifetime stay the same.",
	},
	"splinter_sharpness": {
		"title": "Jagged Splinters", "scope": "form", "policy": "stackable",
		"trigger": "Splintering Strikes fragment contact", "consumer": ["res://wood_affinity.gd", "splinters"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "form",
		        "primary_affinity": "wood"
		      }
		    },
		    {
		      "capability": {
		        "producer": "form",
		        "id": "splintering_strikes",
		        "slot": "form"
		      }
		    }
		  ]
		}, "parameter": "fragment_hp",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Splintering Strikes fragments deal +%s damage to nearby secondary targets.",
		"detail": "Fragments travel in a clear forward fan after a qualifying basic attack hit. The initial hit and trigger interval stay the same.",
	},
	"arc_recharge": {
		"title": "Quick Conduction", "scope": "form", "policy": "stackable",
		"trigger": "Arcing Strikes response on a weapon contact", "consumer": ["res://storm_affinity.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "form",
		        "primary_affinity": "storm"
		      }
		    },
		    {
		      "capability": {
		        "producer": "form",
		        "id": "arcing_strikes",
		        "slot": "form"
		      }
		    }
		  ]
		}, "parameter": "interval_reduction_ms",
		"values": [80, 120, 160, 200], "unit": "ms", "limit": 4,
		"description": "Arcing Strikes can trigger again %s seconds sooner after a qualifying hit.",
		"detail": "The next eligible basic attack hit triggers the arc when it is ready. Misses spend no trigger.",
	},
	"drawing_pressure": {
		"title": "Heavy Compression", "scope": "form", "policy": "stackable",
		"trigger": "Drawing Strikes response on a weapon contact", "consumer": ["res://void_affinity.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "form",
		        "primary_affinity": "void"
		      }
		    },
		    {
		      "capability": {
		        "producer": "form",
		        "id": "drawing_strikes",
		        "slot": "form"
		      }
		    }
		  ]
		}, "parameter": "form_hp",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Drawing Strikes deals +%s compression damage on its first qualifying basic attack hit.",
		"detail": "Draw strength and the trigger interval stay the same. Valid damage still applies when the target resists movement.",
	},
	"catalyst_ember_heat": {
		"title": "Heart of Cinders", "scope": "catalyst", "policy": "stackable",
		"trigger": "Fire Catalyst response applies Burning", "consumer": ["res://fire_combat.gd", "ignite"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "catalyst",
		        "primary_affinity": "fire"
		      }
		    },
		    {
		      "any": [
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "burn",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "ember_burst",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "recipient_ember_response",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "self_ember_response",
		            "slot": "catalyst"
		          }
		        }
		      ]
		    }
		  ]
		},
		"parameter": "stack_bonus", "values": [1, 2, 3, 4], "unit": "stacks", "limit": 4,
		"description": "Fire Catalyst applies %s additional shared Burning stacks per eligible application.",
		"detail": "Applies only to the selected class response. The shared damage per stack, tick interval, decay and native burst damage stay the same.",
	},
	"catalyst_drench_time": {
		"title": "Clinging Dew", "scope": "catalyst", "policy": "stackable",
		"trigger": "Water Catalyst response applies Drenched", "consumer": ["res://water_combat.gd", "drench"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "catalyst",
		        "primary_affinity": "water"
		      }
		    },
		    {
		      "any": [
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "drench",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "radial_wash",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "healing_wash",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "landing_wash",
		            "slot": "catalyst"
		          }
		        }
		      ]
		    }
		  ]
		},
		"parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Drenched applied by your Water Catalyst by %s seconds.",
		"detail": "Applies when your mapped class-ability response Drenches an enemy. The amount of attack damage reduction stays the same.",
	},
	"catalyst_vital_regen": {
		"title": "Greening Chime", "scope": "catalyst", "policy": "stackable",
		"trigger": "Vital Catalyst grants Vitality", "consumer": ["res://vital_combat.gd", "grant"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "catalyst",
		        "primary_affinity": "vital"
		      }
		    },
		    {
		      "any": [
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "self_vitality",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "radial_vitality",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "recipient_vitality",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "landing_vitality",
		            "slot": "catalyst"
		          }
		        }
		      ]
		    }
		  ]
		},
		"parameter": "regen_per_second", "values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Vitality granted by your Vital Catalyst restores +%s HP per second.",
		"detail": "The strongest active regeneration source applies. Max HP and Vitality's duration stay the same.",
	},
	"catalyst_bark_time": {
		"title": "Enduring Bark", "scope": "catalyst", "policy": "stackable",
		"trigger": "Wood Catalyst grants Bark Armor", "consumer": ["res://wood_affinity.gd", "grant"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "catalyst",
		        "primary_affinity": "wood"
		      }
		    },
		    {
		      "any": [
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "self_bark",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "radial_splinters_and_bark",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "recipient_bark",
		            "slot": "catalyst"
		          }
		        },
		        {
		          "capability": {
		            "producer": "catalyst",
		            "id": "landing_bark",
		            "slot": "catalyst"
		          }
		        }
		      ]
		    }
		  ]
		},
		"parameter": "duration_bonus_ms", "values": [250, 400, 550, 700], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Bark Armor granted by your Wood Catalyst by %s seconds while it has capacity.",
		"detail": "Armor still ends when depleted. Absorption and armor capacity stay the same.",
	},
	"quake_impact": {
		"title": "Deep Fault", "scope": "class", "policy": "stackable",
		"trigger": "Native Root Quake hit", "consumer": ["res://outgoing_hits.gd", "skill_targets"],
		"requires": {
		  "all": [
		    {
		      "class": "warden"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Root Quake",
		        "mode": "quake",
		        "slot": "r"
		      }
		    }
		  ]
		}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Root Quake deals +%s damage per hit.",
		"detail": "Applies to Root Quake's native hits. Aftershock and Catalyst damage stay the same.",
	},
	"nova_impact": {
		"title": "Heavy Spores", "scope": "class", "policy": "stackable",
		"trigger": "Native Spore Nova hit", "consumer": ["res://outgoing_hits.gd", "skill_targets"],
		"requires": {
		  "all": [
		    {
		      "class": "weaver"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Spore Nova",
		        "mode": "nova",
		        "slot": "r"
		      }
		    }
		  ]
		}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Spore Nova deals +%s damage per hit.",
		"detail": "Applies to Spore Nova's native hits, including valid hits in Symbiotic Nova's bonus area. Secondary bursts stay the same.",
	},
	"snare_root_time": {
		"title": "Clinging Brambles", "scope": "class", "policy": "stackable",
		"trigger": "Bramble Snare trap contact", "consumer": ["res://combat_traits.gd", "trip_snare"],
		"requires": {
		  "all": [
		    {
		      "class": "ranger"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Bramble Snare",
		        "mode": "snare",
		        "slot": "r"
		      }
		    }
		  ]
		}, "parameter": "bind",
		"values": [150, 250, 350, 450], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Bramble Snare's roots by %s seconds.",
		"detail": "The trap must catch an enemy that can be rooted. Trap lifetime and damage stay the same.",
	},
	"siphon_impact": {
		"title": "Harvest Edge", "scope": "class", "policy": "stackable",
		"trigger": "Native Siphon Cut primary hit", "consumer": ["res://outgoing_hits.gd", "skill_targets"],
		"requires": {
		  "all": [
		    {
		      "class": "reaper"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Siphon Cut",
		        "mode": "siphon",
		        "slot": "r"
		      }
		    }
		  ]
		}, "parameter": "damage",
		"values": [2, 3, 4, 5], "unit": "hp", "limit": 4,
		"description": "Siphon Cut's primary hit deals +%s damage.",
		"detail": "Applies to the primary victim. Siphon Cut's native healing and secondary hits stay the same.",
	},
	"chime_ward_time": {
		"title": "Lasting Resonance", "scope": "class", "policy": "stackable",
		"trigger": "Warding Chime native Ward grant", "consumer": ["res://native_class_actions.gd", "cast"],
		"requires": {
		  "all": [
		    {
		      "class": "oracle"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Warding Chime",
		        "mode": "ward",
		        "slot": "r"
		      }
		    }
		  ]
		}, "parameter": "ward_ms",
		"values": [100, 200, 300, 400], "unit": "ms", "limit": 4,
		"description": "Extends the duration of Warding Chime's native Wards by %s seconds.",
		"detail": "Applies to eligible recipients of Warding Chime. Ward charges and Catalyst responses stay the same.",
	},
	"ordinary_weapon_damage": {
		"title": "Honed Strikes", "scope": "weapon", "policy": "stackable",
		"trigger": "Ordinary attack damage roll", "consumer": ["res://weapon_attack_world.gd", "capture_attack"],
		"requires": {
		  "capability": {
		    "producer": "weapon",
		    "id": "strike"
		  }
		}, "parameter": "strike_damage",
		"values": [1, 2, 3, 4], "unit": "hp", "limit": 4,
		"description": "Basic attacks gain +%s damage.",
		"detail": "Adds to the damage roll before attack delivery and mitigation. Applies to the weapon roll used by basic attacks.",
	},
	"ordinary_weapon_interval": {
		"title": "Light Grip", "scope": "weapon", "policy": "stackable",
		"trigger": "Ordinary attack interval begins", "consumer": ["res://weapon_attack_world.gd", "capture_attack"],
		"requires": {
		  "capability": {
		    "producer": "weapon",
		    "id": "strike"
		  }
		}, "parameter": "strike_interval",
		"values": [20, 35, 50, 65], "unit": "ms", "limit": 4,
		"description": "Increases basic attack speed.",
		"detail": "Copies add their reductions to the time between basic attacks. The displayed attack speed comes from the resulting interval.",
	},
	"run_health": {
		"title": "Hardy Frame", "scope": "general", "policy": "stackable",
		"trigger": "Maximum health resolves for the current expedition", "consumer": ["res://expedition_life.gd", "native_maximum"],
		"requires": {
		  "all": []
		}, "parameter": "max_hp", "values": [3, 5, 7, 9], "unit": "hp", "limit": 4,
		"description": "Gain %s Max HP for this expedition. Current health is unchanged on acquisition.",
		"detail": "Adds to your expedition Max HP. This upgrade ends when you leave the expedition.",
	},
	"run_dodge_recovery": {
		"title": "Quick Footing", "scope": "general", "policy": "stackable",
		"trigger": "Dodge recovery begins", "consumer": ["res://game.gd", "dodge_player"],
		"requires": {
		  "all": []
		}, "parameter": "dodge_interval", "values": [45, 70, 95, 120], "unit": "ms", "limit": 4,
		"description": "Reduces your dodge cooldown by %s seconds.",
		"detail": "Shortens the cooldown assigned by a dodge. Dodge distance and movement rules stay the same.",
	},
	"dew_shelter": {
		"title": "Dew Shelter", "scope": "core", "policy": "unique",
		"trigger": "Living ally touched by Dewfall", "consumer": ["res://water_combat.gd", "on_event"],
		"requires": {
		  "all": [
		    {
		      "plant": {
		        "slot": "core",
		        "primary_affinity": "water"
		      }
		    },
		    {
		      "capability": {
		        "producer": "core",
		        "id": "dewfall",
		        "slot": "core"
		      }
		    }
		  ]
		}, "grants": ["dew_shelter"],
		"parameter": "shelter_ward_ms",
		"fixed": 1200, "unit": "ms", "limit": 1,
		"description": "Dewfall gives living allies it touches a one-charge Ward for %s seconds.",
		"detail": "You qualify at Dewfall's origin. Each living recipient can receive one Ward per cast. Dewfall damage, Drenched and Slow cleansing keep their usual effects. The Ward grants no extra Catalyst response.",
	},
	"echoing_growth": {
		"title": "Echoing Growth", "scope": "class", "policy": "unique",
		"trigger": "Native Spore Nova hits inside the owner’s active Cultivate Bloom", "consumer": ["res://affinity_cards.gd", "bloom_echo"],
		"requires": {
		  "all": [
		    {
		      "class": "weaver"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Spore Nova",
		        "mode": "nova",
		        "slot": "r"
		      }
		    },
		    {
		      "focus": "bloomcaller"
		    },
		    {
		      "capability": {
		        "producer": "class",
		        "id": "Cultivate Bloom",
		        "slot": "q",
		        "field": "growth"
		      }
		    }
		  ]
		},
		"grants": ["echoing_growth"],
		"parameter": "bloom_echo_hp", "fixed": 10, "unit": "hp", "limit": 1,
		"description": "When Spore Nova damages an enemy in your Cultivate Bloom, the bloom deals %s secondary damage to eligible enemies inside.",
		"detail": "Requires Bloomcaller and your own active Cultivate Bloom. The extra pulse happens at most once per Nova. It applies no extra roots or Marks, and triggers no Catalyst, Form, graft or other secondary effects.",
	},
	# CE02 Thorn — provisional, per-copy contributions.
	"bramble_density": {
	  "title": "Bramble Density",
	  "scope": "core",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Thorn Line",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "apply_occupancy"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "core",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "capability": {
	          "producer": "core",
	          "id": "thorn_line",
	          "slot": "core"
	        }
	      }
	    ]
	  },
	  "parameter": "buildup_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Thorn Line applies an additional %s percentage points of your personal Bleed cap.",
	  "detail": "Provisional CE02 tuning. Actual occupants only; the existing one-second application interval and shared cap remain unchanged.",
	  "values": [
	    5,
	    8,
	    11,
	    14
	  ]
	},
	"creeping_briars": {
	  "title": "Creeping Briars",
	  "scope": "core",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Thorn Line",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "release"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "core",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "capability": {
	          "producer": "core",
	          "id": "thorn_line",
	          "slot": "core"
	        }
	      }
	    ]
	  },
	  "parameter": "coverage_cm",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Thorn Line extends %s m farther on each side.",
	  "detail": "Provisional CE02 tuning. Extends the real lane and its preview. It obeys ground support and does not spread Bleed.",
	  "values": [
	    20,
	    30,
	    40,
	    50
	  ]
	},
	"serrated_edge": {
	  "title": "Serrated Edge",
	  "scope": "form",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Eligible direct basic hit",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "barbed_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "direct_bleed_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Eligible basic hits add %s%% of your personal Bleed cap.",
	  "detail": "Provisional CE02 tuning. Additional direct buildup alongside the native stationary patch; no extra contact or proc.",
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"relentless_cuts": {
	  "title": "Relentless Cuts",
	  "scope": "form",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Eligible direct basic hit",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "barbed_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "streak_bleed_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Each successive basic hit on the same enemy adds %s percentage points more Bleed buildup.",
	  "detail": "Provisional CE02 tuning. The first hit starts the sequence. Target changes or three seconds without a hit reset it. Buildup stops at your build-derived cap.",
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ],
	  "tuning": {
	    "window_ms": 3000
	  }
	},
	"opening_wound": {
	  "title": "Opening Wound",
	  "scope": "form",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Eligible direct basic hit",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "barbed_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "opening_bleed_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Your first qualifying basic hit adds %s%% of your personal Bleed cap.",
	  "detail": "Provisional CE02 tuning. Once per enemy while your Bleed contribution remains active; resets after your contribution expires.",
	  "values": [
	    5,
	    8,
	    11,
	    14
	  ]
	},
	"crimson_conduit": {
	  "title": "Crimson Conduit",
	  "scope": "catalyst",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Qualifying Thorn class response",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "apply_occupancy"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "growth",
	              "slot": "catalyst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "lingering_thicket",
	              "slot": "catalyst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "protective_growth",
	              "slot": "catalyst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "departure_growth",
	              "slot": "catalyst"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "buildup_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Catalyst growth applies an additional %s percentage points of your personal Bleed cap.",
	  "detail": "Provisional CE02 tuning. Requires an actual Thorn Catalyst response; empty placement gives no buildup.",
	  "values": [
	    5,
	    8,
	    11,
	    14
	  ]
	},
	"barbed_momentum": {
	  "title": "Barbed Momentum",
	  "scope": "catalyst",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Qualifying Thorn class response",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "apply_occupancy"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "thorn"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "growth",
	              "slot": "catalyst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "lingering_thicket",
	              "slot": "catalyst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "protective_growth",
	              "slot": "catalyst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "departure_growth",
	              "slot": "catalyst"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "momentum_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "A qualifying Catalyst Bleed application prepares +%s damage on your next basic attack.",
	  "detail": "Provisional CE02 tuning. Launch within four seconds; a miss spends it. Only the first direct enemy contact benefits, with no extra proc.",
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ],
	  "tuning": {
	    "duration_ms": 4000
	  }
	},
	"sanguine_growth": {
	  "title": "Sanguine Growth",
	  "scope": "affinity",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Functioning Thorn source",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "apply_occupancy"
	  ],
	  "requires": {
	    "any": [
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "core",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "core",
	              "id": "thorn_line",
	              "slot": "core"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "barbed_strikes",
	              "slot": "form"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "catalyst",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "lingering_thicket",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "protective_growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "departure_growth",
	                  "slot": "catalyst"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "shared_potency_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Increase your personal Bleed tick cap by %s damage across functioning Thorn sources.",
	  "detail": "Provisional CE02 tuning. Counts once per player, not once per slot. Raising the cap supplies no free accumulated Bleed.",
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"unclosing_wounds": {
	  "title": "Unclosing Wounds",
	  "scope": "affinity",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Functioning Thorn source",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "apply_occupancy"
	  ],
	  "requires": {
	    "any": [
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "core",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "core",
	              "id": "thorn_line",
	              "slot": "core"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "barbed_strikes",
	              "slot": "form"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "catalyst",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "lingering_thicket",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "protective_growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "departure_growth",
	                  "slot": "catalyst"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "bleed_duration_ms",
	  "unit": "ms",
	  "limit": 4,
	  "description": "Eligible Bleed applications retain your contribution for an additional %s seconds.",
	  "detail": "Provisional CE02 tuning. Extends your own maintained contribution, not another player’s or the stationary field lifetime.",
	  "values": [
	    250,
	    400,
	    550,
	    700
	  ]
	},
	"hemorrhagic_rupture": {
	  "title": "Hemorrhagic Rupture",
	  "scope": "affinity",
	  "family": "thorn",
	  "policy": "stackable",
	  "trigger": "Functioning Thorn source",
	  "consumer": [
	    "res://thorn_affinity.gd",
	    "on_death"
	  ],
	  "requires": {
	    "any": [
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "core",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "core",
	              "id": "thorn_line",
	              "slot": "core"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "barbed_strikes",
	              "slot": "form"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "catalyst",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "lingering_thicket",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "protective_growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "departure_growth",
	                  "slot": "catalyst"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "death_burst_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "A heavily Bleeding enemy’s death bursts for %s%% of its accumulated Bleed tick damage.",
	  "detail": "Provisional CE02 tuning. Requires at least 50% of the shared cap. Hits other enemies within 3 m and clear line. One strongest eligible owner supplies the burst; it spreads no Bleed and cannot chain death bursts.",
	  "values": [
	    50,
	    75,
	    100,
	    125
	  ],
	  "tuning": {
	    "threshold_percent": 50,
	    "radius_m": 3.0
	  }
	},
	"bloodletting": {
	  "title": "Bloodletting",
	  "scope": "affinity",
	  "family": "thorn",
	  "policy": "unique",
	  "trigger": "Functioning Thorn source",
	  "consumer": [
	    "res://card_active_actions.gd",
	    "command"
	  ],
	  "requires": {
	    "any": [
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "core",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "core",
	              "id": "thorn_line",
	              "slot": "core"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "barbed_strikes",
	              "slot": "form"
	            }
	          }
	        ]
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "catalyst",
	              "primary_affinity": "thorn"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "lingering_thicket",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "protective_growth",
	                  "slot": "catalyst"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "departure_growth",
	                  "slot": "catalyst"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "bloodletting_unlock",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Unlock Bloodletting: deal twice an aimed enemy’s accumulated Bleed tick damage without consuming Bleed.",
	  "detail": "Provisional CE02 tuning. Additional configurable card action, default Z. Requires an eligible Bleeding enemy within 8 m and combat sight; eight-second cooldown. Does not trigger Form, Catalyst, grafts or recursive death bursts.",
	  "fixed": 1,
	  "tuning": {
	    "cooldown_ms": 8000,
	    "range_m": 8.0,
	    "damage_percent": 200,
	    "min_aim_dot": 0.3
	  },
	  "grants": [
	    "bloodletting"
	  ],
	  "active": true
	},
	# CE02 Frost — independently acquired source, rupture and propagation cards.
	"fractured_bloom": {
	  "title": "Fractured Bloom",
	  "scope": "core",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible core Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "core",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "capability": {
	          "producer": "core",
	          "id": "rime_bloom",
	          "slot": "core"
	        }
	      }
	    ]
	  },
	  "parameter": "source_shatter_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Rime Bloom applications gain +%s maximum shatter damage.",
	  "detail": "Provisional CE02 tuning. Each applied stack freezes one third of this source-specific increase.",
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"returning_winter": {
	  "title": "Returning Winter",
	  "scope": "core",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible core Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "bloom_phase"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "core",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "capability": {
	          "producer": "core",
	          "id": "rime_bloom",
	          "slot": "core"
	        }
	      }
	    ]
	  },
	  "parameter": "closing_stacks",
	  "unit": "stacks",
	  "limit": 4,
	  "description": "Rime Bloom closing petals apply %s additional Brittle stacks.",
	  "detail": "Provisional CE02 tuning. Separate from Avalanche and Shatterwave. Every completed three-stack group ruptures normally.",
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"fracturing_edge": {
	  "title": "Fracturing Edge",
	  "scope": "form",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible form Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "brittle_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "source_shatter_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Basic-attack Brittle gains +%s maximum shatter damage.",
	  "detail": "Provisional CE02 tuning. Only the source-weighted contribution of eligible basic-hit stacks changes.",
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"relentless_chill": {
	  "title": "Relentless Chill",
	  "scope": "form",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible form Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "brittle_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "extra_stack_milli",
	  "unit": "milli_stacks",
	  "limit": 4,
	  "description": "Each eligible basic hit earns %s additional Brittle stack credit.",
	  "detail": "Provisional CE02 tuning. Whole credits apply extra stacks to that hit; fractional credit carries between hits. No random roll.",
	  "values": [
	    250,
	    400,
	    550,
	    700
	  ]
	},
	"cold_precision": {
	  "title": "Cold Precision",
	  "scope": "form",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible form Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "ordinary_bonus"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "brittle_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "precision_hp_per_stack",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Basic hits deal +%s damage per Brittle stack already on their target.",
	  "detail": "Provisional CE02 tuning. Counts the current zero, one or two shared stacks before this hit applies its Form. No secondary contact.",
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"winters_judgment": {
	  "title": "Winter's Judgment",
	  "scope": "catalyst",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible catalyst Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "brittle"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "brittle_burst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_frost_response"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "self_frost_response"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "source_shatter_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Class-action Brittle gains +%s maximum shatter damage.",
	  "detail": "Provisional CE02 tuning. Only stacks actually supplied by the equipped Frost Catalyst gain this frozen contribution.",
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"spreading_chill": {
	  "title": "Spreading Chill",
	  "scope": "catalyst",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible catalyst Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "brittle"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "brittle_burst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_frost_response"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "self_frost_response"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "side_shatter_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "A qualifying class action adds one nearby Brittle stack at %s%% shatter potency.",
	  "detail": "Provisional CE02 tuning. Once per action, to another enemy within 2.4 m and clear line. This secondary stack cannot launch further spreads or secondary bursts.",
	  "values": [
	    10,
	    15,
	    20,
	    25
	  ],
	  "tuning": {
	    "radius_m": 2.4
	  }
	},
	"shatter_rhythm": {
	  "title": "Shatter Rhythm",
	  "scope": "catalyst",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible catalyst Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "frost"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "brittle"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "brittle_burst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_frost_response"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "self_frost_response"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "rhythm_shatter_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "A Catalyst rupture prepares +%s shatter potency for that class action's next use.",
	  "detail": "Provisional CE02 tuning. Same Q or R slot, within five seconds. Claimed on its first eligible application; refused or empty casts do not spend it. It cannot empower its own cast.",
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ],
	  "tuning": {
	    "duration_ms": 5000
	  }
	},
	"crystalline_fracture": {
	  "title": "Crystalline Fracture",
	  "scope": "affinity",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "frost"
	          ]
	        }
	      },
	      {
	        "any": [
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "core",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "core",
	                  "id": "rime_bloom",
	                  "slot": "core"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "form",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "form",
	                  "id": "brittle_strikes",
	                  "slot": "form"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "catalyst",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "any": [
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_frost_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_frost_response"
	                    }
	                  }
	                ]
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "shared_potency_hp",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Increase maximum shatter damage by %s across functioning Frost sources.",
	  "detail": "Provisional CE02 tuning. Counts once across equipped sources; each stack freezes one third when applied.",
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"deep_freeze": {
	  "title": "Deep Freeze",
	  "scope": "affinity",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "apply"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "frost"
	          ]
	        }
	      },
	      {
	        "any": [
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "core",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "core",
	                  "id": "rime_bloom",
	                  "slot": "core"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "form",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "form",
	                  "id": "brittle_strikes",
	                  "slot": "form"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "catalyst",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "any": [
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_frost_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_frost_response"
	                    }
	                  }
	                ]
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "slow_bonus_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Each active Brittle stack adds %s percentage points more movement Slow.",
	  "detail": "Provisional CE02 tuning. Preserves the one- and two-stack progression and the existing boss Slow scale. Grants no root.",
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"rime_lock": {
	  "title": "Rime Lock",
	  "scope": "affinity",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "rupture_effects"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "frost"
	          ]
	        }
	      },
	      {
	        "any": [
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "core",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "core",
	                  "id": "rime_bloom",
	                  "slot": "core"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "form",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "form",
	                  "id": "brittle_strikes",
	                  "slot": "form"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "catalyst",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "any": [
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_frost_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_frost_response"
	                    }
	                  }
	                ]
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "rupture_root_ms",
	  "unit": "ms",
	  "limit": 4,
	  "description": "Your eligible Brittle ruptures root surviving enemies for %s seconds.",
	  "detail": "Provisional CE02 tuning. Uses the longest eligible captured owner duration without shortening an existing root. Baseline rupture remains root-free.",
	  "values": [
	    150,
	    250,
	    350,
	    450
	  ]
	},
	"shatterwave": {
	  "title": "Shatterwave",
	  "scope": "affinity",
	  "family": "frost",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "rupture_effects"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "frost"
	          ]
	        }
	      },
	      {
	        "any": [
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "core",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "core",
	                  "id": "rime_bloom",
	                  "slot": "core"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "form",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "form",
	                  "id": "brittle_strikes",
	                  "slot": "form"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "catalyst",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "any": [
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_frost_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_frost_response"
	                    }
	                  }
	                ]
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "shatterwave_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Your eligible ruptures deal %s%% additional rupture damage in an area.",
	  "detail": "Provisional CE02 tuning. One strongest eligible captured owner emits immediate secondary damage within 2.4 m, including the original target if alive. No Brittle spread or secondary proc.",
	  "values": [
	    20,
	    30,
	    40,
	    50
	  ],
	  "tuning": {
	    "radius_m": 2.4
	  }
	},
	"avalanche": {
	  "title": "Avalanche",
	  "scope": "affinity",
	  "family": "frost",
	  "policy": "unique",
	  "trigger": "Eligible affinity Frost application or rupture",
	  "consumer": [
	    "res://frost_combat.gd",
	    "rupture_effects"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "frost"
	          ]
	        }
	      },
	      {
	        "any": [
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "core",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "core",
	                  "id": "rime_bloom",
	                  "slot": "core"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "form",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "form",
	                  "id": "brittle_strikes",
	                  "slot": "form"
	                }
	              }
	            ]
	          },
	          {
	            "all": [
	              {
	                "plant": {
	                  "slot": "catalyst",
	                  "primary_affinity": "frost"
	                }
	              },
	              {
	                "any": [
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "brittle_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_frost_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_frost_response"
	                    }
	                  }
	                ]
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "avalanche_unlock",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Your eligible ruptures spread one attributed Brittle stack to nearby enemies.",
	  "detail": "Provisional CE02 tuning. Within 2.4 m and clear line. The stack retains its source potency. A propagation-triggered rupture cannot emit another Avalanche or secondary burst; later legitimate attacks can.",
	  "fixed": 1,
	  "tuning": {
	    "radius_m": 2.4
	  },
	  "grants": [
	    "avalanche"
	  ]
	},
}


static func rise(floor_number: int) -> Array[float]:
	var curve: Array = PLAYTEST.rarity_curve
	var left: Array = curve.front()
	for right: Array in curve.slice(1):
		if floor_number <= int(right[0]):
			var fraction := clampf(float(floor_number - int(left[0])) / float(int(right[0]) - int(left[0])), 0.0, 1.0)
			var blended: Array[float] = []
			for index in RARITIES.size():
				blended.append(lerpf(float(left[1][index]), float(right[1][index]), fraction))
			return blended
		left = right
	var tail: Array[float] = []
	tail.assign(left[1])
	return tail


static func effect_text(definition: Dictionary, value: int) -> String:
	var text: String = definition.description
	if "%s" not in text:
		return text
	var number := str(value) if definition.unit in ["hp","stacks","percent","unlock"] else ("%.3f" % (value / 1000.0)).rstrip("0").trim_suffix(".")
	if definition.unit == "cm": number = ("%.2f" % (value / 100.0)).rstrip("0").trim_suffix(".")
	return text % number


static func contribution_label(definition: Dictionary) -> String:
	if definition.get("family", "") != "": return str(definition.parameter).replace("_", " ").capitalize()
	match definition.parameter:
		"stack_bonus": return "Burning stacks per application"
		"tick_hp": return "Personal Bleed tick cap"
		"max_hp": return "Max HP bonus"
		"regen_per_second": return "Regeneration bonus"
		"strike_interval": return "Basic attack timing"
		"interval_reduction_ms": return "Arc trigger interval reduction"
		"dodge_interval": return "Dodge cooldown reduction"
	return "Duration bonus" if definition.unit == "ms" else "Damage bonus"


static func contribution(definition: Dictionary, value: int) -> String:
	if definition.unit == "percent": return "+%d%%" % value
	if definition.unit == "cm": return "+%.2f m" % (value / 100.0)
	if definition.unit == "unlock": return "Unlocked" if value > 0 else "Not acquired"
	match definition.parameter:
		"stack_bonus": return "+%d stacks per application" % value
		"tick_hp": return "+%d maximum Bleed damage per tick" % value
		"regen_per_second": return "+%d HP/s" % value
		"max_hp": return "+%d Max HP" % value
		"strike_interval": return "%s s less between basic attacks" % ("%.3f" % (value / 1000.0)).rstrip("0").trim_suffix(".")
	if definition.unit == "stacks": return "+%d stacks" % value
	if definition.unit == "milli_stacks": return "+%.3f stack credit per hit" % (value/1000.0)
	if definition.unit == "hp":
		return "+%d damage" % value
	if value == 0:
		return "+0 s"
	var seconds := ("%.2f" if value % 10 == 0 else "%.3f") % (value / 1000.0)
	return "+%s s" % seconds
