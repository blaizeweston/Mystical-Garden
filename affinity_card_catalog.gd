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
	  "label": "Bleed buildup per application",
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
	  "label": "Thorn Line extension per side",
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
	  "label": "Extra Bleed per basic hit",
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
	  "label": "Buildup per successive hit",
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
	  "label": "Opening buildup",
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
	  "label": "Bleed buildup per class application",
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
	  "label": "Prepared direct damage",
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
	  "label": "Personal Bleed tick cap bonus",
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
	  "label": "Bleed retention duration",
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
	  "label": "Death burst damage scaling",
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
	  "label": "Core shatter potency",
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
	  "label": "Additional closing stacks",
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
	  "label": "Basic-hit shatter potency",
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
	  "label": "Additional stack credit per hit",
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
	  "label": "Direct damage per existing stack",
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
	  "label": "Class-action shatter potency",
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
	  "label": "Neighboring stack potency",
	  "parameter": "side_shatter_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "A qualifying class action adds one nearby Brittle stack at %s%% shatter potency.",
	  "detail": "Provisional CE02 tuning. Once per action, to another enemy within 2.4 m and clear line. A resulting rupture may use acquired root and wave effects, but cannot launch another spread.",
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
	  "label": "Prepared shatter potency",
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
	  "label": "Personal shatter potency bonus",
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
	  "label": "Slow per Brittle stack",
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
	  "label": "Rupture root duration",
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
	  "label": "Area damage per rupture",
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
	  "detail": "Provisional CE02 tuning. Within 2.4 m and clear line. The stack retains its source potency. A propagation-triggered rupture can use acquired Rime Lock and Shatterwave, but cannot emit another Avalanche; later legitimate attacks can.",
	  "fixed": 1,
	  "tuning": {
	    "radius_m": 2.4
	  },
	  "grants": [
	    "avalanche"
	  ]
	},
	# CE02 Fire — stack application, sustained pressure and distinct secondary effects.
	"kindled_roots": {
	  "title": "Kindled Roots",
	  "scope": "core",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible core Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "ignite"
	  ],
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
	  },
	  "label": "Burning stacks per Core application",
	  "parameter": "stack_bonus",
	  "unit": "stacks",
	  "limit": 4,
	  "description": "Ember Wake applies %s additional Burning stacks.",
	  "detail": "Provisional CE02 tuning. Applies on first contact and the existing 750 ms maintenance cadence; no extra initial damage.",
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"lingering_coals": {
	  "title": "Lingering Coals",
	  "scope": "core",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible core Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "field"
	  ],
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
	  },
	  "label": "Trail duration bonus",
	  "parameter": "field_duration_ms",
	  "unit": "ms",
	  "limit": 4,
	  "description": "Ember Wake’s trail lasts an additional %s seconds.",
	  "detail": "Provisional CE02 tuning. Extends the real field, visual lifetime and cast expiry. Stack maintenance still has its existing per-enemy interval.",
	  "values": [
	    250,
	    400,
	    550,
	    700
	  ]
	},
	"stoking_strikes": {
	  "title": "Stoking Strikes",
	  "scope": "form",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible form Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "ignite"
	  ],
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
	  },
	  "label": "Extra stacks per successive attack",
	  "parameter": "stoking_stacks",
	  "unit": "stacks",
	  "limit": 4,
	  "description": "Each consecutive basic attack adds %s more Burning stacks after the first.",
	  "detail": "Provisional CE02 tuning. One sequence step per attack, including volleys. Three seconds without an eligible hit resets the sequence. Target changes do not reset Fire pressure.",
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ],
	  "tuning": {
	    "window_ms": 3000
	  }
	},
	"feverish_tempo": {
	  "title": "Feverish Tempo",
	  "scope": "form",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible form Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "tempo_percent"
	  ],
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
	  },
	  "label": "Attack speed per sequence step",
	  "parameter": "tempo_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Successive basic hits on Burning enemies add %s%% attack speed per sequence step.",
	  "detail": "Provisional CE02 tuning. After the first hit, the temporary speed lasts two seconds and refreshes on qualifying hits. The three-second hit sequence and current basic-attack timing limit still apply.",
	  "values": [
	    3,
	    4,
	    5,
	    6
	  ],
	  "tuning": {
	    "duration_ms": 2000
	  }
	},
	"incendiary_followthrough": {
	  "title": "Incendiary Followthrough",
	  "scope": "catalyst",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible catalyst Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "ignite"
	  ],
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
	              "id": "burn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "ember_burst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_ember_response"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "self_ember_response"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "label": "Extra stacks against Burning enemies",
	  "parameter": "burning_target_stacks",
	  "unit": "stacks",
	  "limit": 4,
	  "description": "Catalyst applications add %s extra stacks against enemies already Burning.",
	  "detail": "Provisional CE02 tuning. Checks the shared Burning before this application; no extra class contact or Catalyst activation.",
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"ember_resonance": {
	  "title": "Ember Resonance",
	  "scope": "catalyst",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible catalyst Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "ignite"
	  ],
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
	              "id": "burn"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "ember_burst"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_ember_response"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "self_ember_response"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "label": "Nearby stack application strength",
	  "parameter": "resonance_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "A qualifying Catalyst application gives nearby enemies %s%% of its Burning stack application.",
	  "detail": "Provisional CE02 tuning. Once per class action, within 2.4 m and clear line, excluding the original enemy. Secondary applications cannot trigger another resonance or Flashover.",
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
	"banked_heat": {
	  "title": "Banked Heat",
	  "scope": "affinity",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "advance"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "fire"
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
	          },
	          {
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
	          },
	          {
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
	                      "id": "burn"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "ember_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_ember_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_ember_response"
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
	  "label": "Decay efficiency",
	  "parameter": "retention_rating",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Your Burning contributions gain %s%% decay efficiency.",
	  "detail": "Provisional CE02 tuning. Your assigned decay loss is divided by 1 + total efficiency/100, with fractional loss carried between decays. Other owners retain their normal rules; no fixed intensity ceiling.",
	  "values": [
	    10,
	    15,
	    20,
	    25
	  ]
	},
	"feeding_the_flames": {
	  "title": "Feeding the Flames",
	  "scope": "affinity",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "ignite"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "fire"
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
	          },
	          {
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
	          },
	          {
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
	                      "id": "burn"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "ember_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_ember_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_ember_response"
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
	  "label": "Burning stacks per application",
	  "parameter": "stack_bonus",
	  "unit": "stacks",
	  "limit": 4,
	  "description": "Add %s Burning stacks per eligible application across functioning Fire slots.",
	  "detail": "Provisional CE02 tuning. Core, Form and Catalyst cooperate. This adds no duplicate application or secondary activation.",
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"flashover": {
	  "title": "Flashover",
	  "scope": "affinity",
	  "family": "fire",
	  "policy": "stackable",
	  "trigger": "Eligible affinity Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "flashover"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "fire"
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
	          },
	          {
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
	          },
	          {
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
	                      "id": "burn"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "ember_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_ember_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_ember_response"
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
	  "label": "Damage per consumed Burning stack",
	  "parameter": "flashover_percent",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Flashover deals damage equal to %s%% of the Burning stacks actually consumed.",
	  "detail": "Provisional CE02 tuning. Your native Fire application at 8+ stacks consumes 25% and leaves at least one stack. One shared two-second trigger interval per enemy; 2.4 m clear-line area. Secondary damage cannot trigger Flashover.",
	  "values": [
	    50,
	    75,
	    100,
	    125
	  ],
	  "tuning": {
	    "threshold_stacks": 8,
	    "consume_percent": 25,
	    "minimum_remaining": 1,
	    "interval_ms": 2000,
	    "radius_m": 2.4
	  }
	},
	"wildfire": {
	  "title": "Wildfire",
	  "scope": "affinity",
	  "family": "fire",
	  "policy": "unique",
	  "trigger": "Eligible affinity Fire application or Burning tick",
	  "consumer": [
	    "res://fire_combat.gd",
	    "spread"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "tags_all": [
	            "fire"
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
	          },
	          {
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
	          },
	          {
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
	                      "id": "burn"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "ember_burst"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_ember_response"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "self_ember_response"
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
	  "parameter": "wildfire_unlock",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Burning at 8+ intensity spreads half its stacks to nearby enemies once per second.",
	  "detail": "Provisional CE02 tuning. One eligible owner supplies each attributed 2.4 m spread. Does not consume the original. Propagated-only contributions cannot spread again; a real native application can enable later spread. Independent from Flashover.",
	  "fixed": 1,
	  "tuning": {
	    "threshold_stacks": 8,
	    "spread_percent": 50,
	    "interval_ms": 1000,
	    "radius_m": 2.4
	  },
	  "grants": [
	    "wildfire"
	  ]
	},
	# CE03 Water — values and units are the authoring authority.
	"gathering_clouds": {
	  "title": "Gathering Clouds",
	  "family": "water",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "One application per contacted enemy",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "saturation_bonus",
	  "label": "Gathering Clouds contribution",
	  "unit": "pressure",
	  "limit": 4,
	  "description": "Dewfall adds +%s Saturation per enemy contact.",
	  "detail": "Provisional CE03 tuning. One application per contacted enemy. Does not change impact damage.",
	  "tuning": {},
	  "values": [
	    8,
	    12,
	    16,
	    20
	  ]
	},
	"widening_curtain": {
	  "title": "Widening Curtain",
	  "family": "water",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Actual curtain and preview use the same width",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "width_cm",
	  "label": "Widening Curtain contribution",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Dewfall gains +%s m half-width.",
	  "detail": "Provisional CE03 tuning. Actual curtain and preview use the same width.",
	  "tuning": {},
	  "values": [
	    15,
	    25,
	    35,
	    45
	  ]
	},
	"restorative_rain": {
	  "title": "Restorative Rain",
	  "family": "water",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Once per recipient per cast, including the caster at formation",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "direct_heal_hp",
	  "label": "Restorative Rain contribution",
	  "unit": "healing_hp",
	  "limit": 4,
	  "description": "Dewfall restores +%s HP to each living ally it touches.",
	  "detail": "Provisional CE03 tuning. Once per recipient per cast, including the caster at formation. No extra Ward or Catalyst activation.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"saturating_strikes": {
	  "title": "Saturating Strikes",
	  "family": "water",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Only functioning Water Form contacts qualify",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "water"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "drenching_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "saturation_bonus",
	  "label": "Saturating Strikes contribution",
	  "unit": "pressure",
	  "limit": 4,
	  "description": "Qualifying basic hits add +%s Saturation.",
	  "detail": "Provisional CE03 tuning. Only functioning Water Form contacts qualify.",
	  "tuning": {},
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"rolling_current": {
	  "title": "Rolling Current",
	  "family": "water",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Starts after the first eligible attack",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "water"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "drenching_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "sequence_saturation",
	  "label": "Rolling Current contribution",
	  "unit": "pressure",
	  "limit": 4,
	  "description": "Each successive basic attack adds another +%s Saturation.",
	  "detail": "Provisional CE03 tuning. Starts after the first eligible attack. Resets after a 3-second gap. A volley advances the sequence only once.",
	  "tuning": {
	    "gap_ms": 3000
	  },
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"pressure_point": {
	  "title": "Pressure Point",
	  "family": "water",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Adds native damage to one primary direct contact per attack",
	  "consumer": [
	    "res://water_combat.gd",
	    "ordinary_bonus"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "water"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "drenching_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "pressure_hit_hp",
	  "label": "Pressure Point contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Your first basic-hit target at 50+ Saturation takes +%s damage.",
	  "detail": "Provisional CE03 tuning. Adds native damage to one primary direct contact per attack. No separate hit or proc.",
	  "tuning": {
	    "threshold": 50
	  },
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"refreshing_strikes": {
	  "title": "Refreshing Strikes",
	  "family": "water",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Lasts 4 seconds",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "water"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "drenching_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "prepared_heal_hp",
	  "label": "Refreshing Strikes contribution",
	  "unit": "healing_hp",
	  "limit": 4,
	  "description": "A basic hit prepares +%s HP of personal Surge healing.",
	  "detail": "Provisional CE03 tuning. Lasts 4 seconds. The next accepted Surge uses your weighted share of the bonus, then spends it. Repeated hits refresh rather than stack preparations.",
	  "tuning": {
	    "duration_ms": 4000
	  },
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"tidal_resonance": {
	  "title": "Tidal Resonance",
	  "family": "water",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Only mapped Water Catalyst applications qualify",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
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
	              "id": "drench"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "radial_wash"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "healing_wash"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_wash"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "saturation_bonus",
	  "label": "Tidal Resonance contribution",
	  "unit": "pressure",
	  "limit": 4,
	  "description": "Eligible class responses add +%s Saturation.",
	  "detail": "Provisional CE03 tuning. Only mapped Water Catalyst applications qualify.",
	  "tuning": {},
	  "values": [
	    6,
	    9,
	    12,
	    15
	  ]
	},
	"cleansing_response": {
	  "title": "Cleansing Response",
	  "family": "water",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Expands ally ordinary-Slow cleansing only, not enemy Drench area or healing triggers",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
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
	              "id": "radial_wash"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "healing_wash"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_wash"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "cleanse_radius_cm",
	  "label": "Cleansing Response contribution",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Catalyst cleansing washes reach +%s m farther.",
	  "detail": "Provisional CE03 tuning. Expands ally ordinary-Slow cleansing only, not enemy Drench area or healing triggers.",
	  "tuning": {},
	  "values": [
	    20,
	    30,
	    40,
	    50
	  ]
	},
	"crushing_surf": {
	  "title": "Crushing Surf",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Each wave carries only the share of threshold pressure you actually supplied",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "surge_hp",
	  "label": "Crushing Surf contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Your full-share outgoing Surge potency gains +%s damage.",
	  "detail": "Provisional CE03 tuning. Each wave carries only the share of threshold pressure you actually supplied.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"restorative_surge": {
	  "title": "Restorative Surge",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Independent from damage",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "surge_heal_hp",
	  "label": "Restorative Surge contribution",
	  "unit": "healing_hp",
	  "limit": 4,
	  "description": "Your full-share returning Surge potency gains +%s healing.",
	  "detail": "Provisional CE03 tuning. Independent from damage. Once per returning wave per living recipient.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"wide_wake": {
	  "title": "Wide Wake",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Outgoing and gentler returning coverage both improve",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "surge_width_cm",
	  "label": "Wide Wake contribution",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Your Surge waves gain +%s m half-width.",
	  "detail": "Provisional CE03 tuning. Outgoing and gentler returning coverage both improve. Solid cover still stops the wave.",
	  "tuning": {},
	  "values": [
	    15,
	    25,
	    35,
	    45
	  ]
	},
	"breakwater": {
	  "title": "Breakwater",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "One native charge per contacted living recipient per wave",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "surge_ward_ms",
	  "label": "Breakwater contribution",
	  "unit": "ms",
	  "limit": 4,
	  "description": "Returning tides grant one Ward for %s s.",
	  "detail": "Provisional CE03 tuning. One native charge per contacted living recipient per wave. Uses ordinary Ward merging, not additional Catalyst claims.",
	  "tuning": {},
	  "values": [
	    400,
	    600,
	    800,
	    1000
	  ]
	},
	"focused_current": {
	  "title": "Focused Current",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Only the captured triggering spawn qualifies",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "focus_percent",
	  "label": "Focused Current contribution",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Outgoing Surge deals +%s%% damage to its triggering enemy.",
	  "detail": "Provisional CE03 tuning. Only the captured triggering spawn qualifies. Other targets keep ordinary wave damage.",
	  "tuning": {},
	  "values": [
	    20,
	    30,
	    40,
	    50
	  ]
	},
	"undertow": {
	  "title": "Undertow",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Uses native terrain-limited enemy displacement and resistance",
	  "consumer": [
	    "res://water_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "surge_push_cm",
	  "label": "Undertow contribution",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Outgoing tides push +%s m farther.",
	  "detail": "Provisional CE03 tuning. Uses native terrain-limited enemy displacement and resistance. Resistant enemies still take damage.",
	  "tuning": {},
	  "values": [
	    10,
	    15,
	    20,
	    25
	  ]
	},
	"monsoon": {
	  "title": "Monsoon",
	  "family": "water",
	  "scope": "affinity",
	  "policy": "unique",
	  "trigger": "Each extra ring carries 35% of your own weighted damage and healing",
	  "consumer": [
	    "res://water_combat.gd",
	    "drench"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "drenching_strikes",
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
	              "primary_affinity": "water"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "drench"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "healing_wash"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_wash"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "monsoon_unlock",
	  "label": "Monsoon contribution",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Surge also creates two expanding and returning Water rings.",
	  "detail": "Provisional CE03 tuning. Each extra ring carries 35% of your own weighted damage and healing. Keeps normal Surge, does not add pressure or recursively activate Monsoon.",
	  "tuning": {
	    "waves": 2,
	    "share_percent": 35,
	    "radius_m": 3.0,
	    "gap_ms": 180
	  },
	  "fixed": 1,
	  "grants": [
	    "monsoon"
	  ]
	},

	# CE03 Wood — values and units are the authoring authority.
	"thickened_growth": {
	  "title": "Thickened Growth",
	  "family": "wood",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Adds real protective capacity to each native grant",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "core_capacity",
	  "label": "Thickened Growth contribution",
	  "unit": "bark",
	  "limit": 4,
	  "description": "Ironbark grants +%s Bark capacity.",
	  "detail": "Provisional CE03 tuning. Adds real protective capacity to each native grant. No total pool ceiling.",
	  "tuning": {},
	  "values": [
	    6,
	    9,
	    12,
	    15
	  ]
	},
	"splinterguard": {
	  "title": "Splinterguard",
	  "family": "wood",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Requires an actual direct hostile attack absorbed by your Ironbark",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "guard_fragments",
	  "label": "Splinterguard contribution",
	  "unit": "fragments",
	  "limit": 4,
	  "description": "Ironbark absorption can release +%s retaliatory splinters.",
	  "detail": "Provisional CE03 tuning. Requires an actual direct hostile attack absorbed by your Ironbark. Once per source/recipient each second. Coexists with Splinterback.",
	  "tuning": {
	    "interval_ms": 1000
	  },
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"bursting_canopy": {
	  "title": "Bursting Canopy",
	  "family": "wood",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Uses native fragment damage and terrain collision",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "activation_fragments",
	  "label": "Bursting Canopy contribution",
	  "unit": "fragments",
	  "limit": 4,
	  "description": "Ironbark activation fires %s radial splinters.",
	  "detail": "Provisional CE03 tuning. Uses native fragment damage and terrain collision. Each enemy can be hit once per volley.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"splinter_volley": {
	  "title": "Splinter Volley",
	  "family": "wood",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Adds separate initial fragment targets to the native forward fan",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "extra_fragments",
	  "label": "Splinter Volley contribution",
	  "unit": "fragments",
	  "limit": 4,
	  "description": "Eligible splintering strikes gain +%s fragments.",
	  "detail": "Provisional CE03 tuning. Adds separate initial fragment targets to the native forward fan. The existing Form interval is unchanged.",
	  "tuning": {},
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"hardwood_tips": {
	  "title": "Hardwood Tips",
	  "family": "wood",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Only enemies along the actual fragment lane qualify",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "fragment_penetrations",
	  "label": "Hardwood Tips contribution",
	  "unit": "penetrations",
	  "limit": 4,
	  "description": "Each fragment can penetrate +%s additional enemies.",
	  "detail": "Provisional CE03 tuning. Only enemies along the actual fragment lane qualify. Solid cover stops it. Each enemy is damaged at most once per volley, across all fragments.",
	  "tuning": {
	    "lane_radius_m": 0.18,
	    "extra_reach_m": 2.0
	  },
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"concentrated_grain": {
	  "title": "Concentrated Grain",
	  "family": "wood",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Strengthens the native initiating impact even against a single enemy",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "concentrated_hp",
	  "label": "Concentrated Grain contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Splintering Strikes deal +%s damage to their primary enemy.",
	  "detail": "Provisional CE03 tuning. Strengthens the native initiating impact even against a single enemy. Does not produce another contact.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"shattering_canopy": {
	  "title": "Shattering Canopy",
	  "family": "wood",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Once per class action, at the native contact or designated attack center",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "wood"
	        }
	      },
	      {
	        "capability": {
	          "producer": "catalyst",
	          "id": "self_bark"
	        }
	      }
	    ]
	  },
	  "parameter": "offense_fragments",
	  "label": "Shattering Canopy contribution",
	  "unit": "fragments",
	  "limit": 4,
	  "description": "Offensive class contacts release %s extra splinters.",
	  "detail": "Provisional CE03 tuning. Once per class action, at the native contact or designated attack center. Does not create additional Catalyst contacts.",
	  "tuning": {},
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"reinforced_growth": {
	  "title": "Reinforced Growth",
	  "family": "wood",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Uses independent native grant lifetimes and ordinary partial absorption",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
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
	              "id": "self_bark"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "radial_splinters_and_bark"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_bark"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_bark"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "catalyst_capacity",
	  "label": "Reinforced Growth contribution",
	  "unit": "bark",
	  "limit": 4,
	  "description": "Compatible Catalyst responses grant +%s Bark capacity.",
	  "detail": "Provisional CE03 tuning. Uses independent native grant lifetimes and ordinary partial absorption.",
	  "tuning": {},
	  "values": [
	    4,
	    6,
	    8,
	    10
	  ]
	},
	"heartwood_pressure": {
	  "title": "Heartwood Pressure",
	  "family": "wood",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Uses actual unexpired remaining Bark when each volley begins",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "any": [
	          {
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
	          },
	          {
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
	                      "id": "self_bark"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "radial_splinters_and_bark"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "recipient_bark"
	                    }
	                  },
	                  {
	                    "capability": {
	                      "producer": "catalyst",
	                      "id": "landing_bark"
	                    }
	                  }
	                ]
	              }
	            ]
	          }
	        ]
	      },
	      {
	        "any": [
	          {
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
	          },
	          {
	            "owned": {
	              "kind": "card",
	              "id": "splinterguard"
	            }
	          },
	          {
	            "owned": {
	              "kind": "card",
	              "id": "bursting_canopy"
	            }
	          },
	          {
	            "owned": {
	              "kind": "card",
	              "id": "shattering_canopy"
	            }
	          },
	          {
	            "owned": {
	              "kind": "card",
	              "id": "splinterback"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "held_bark_percent",
	  "label": "Heartwood Pressure contribution",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Splinter damage gains %s%% of your held Bark.",
	  "detail": "Provisional CE03 tuning. Uses actual unexpired remaining Bark when each volley begins. Requires a functioning Bark source and a real splinter producer. Does not spend protection.",
	  "tuning": {},
	  "values": [
	    5,
	    8,
	    11,
	    14
	  ]
	},
	"splinterback": {
	  "title": "Splinterback",
	  "family": "wood",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Requires an actual direct hostile attack",
	  "consumer": [
	    "res://wood_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
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
	                  "id": "self_bark"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_splinters_and_bark"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_bark"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_bark"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "retaliation_fragments",
	  "label": "Splinterback contribution",
	  "unit": "fragments",
	  "limit": 4,
	  "description": "Your Bark absorption can release %s retaliatory splinters.",
	  "detail": "Provisional CE03 tuning. Requires an actual direct hostile attack. Once per source/recipient each second. Adds to separately learned Splinterguard.",
	  "tuning": {
	    "interval_ms": 1000
	  },
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"splinterburst": {
	  "title": "Splinterburst",
	  "family": "wood",
	  "scope": "affinity",
	  "policy": "unique",
	  "trigger": "Deals 1 damage per actual Bark consumed within 3 m",
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
	      },
	      {
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
	                  "id": "self_bark"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_splinters_and_bark"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_bark"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_bark"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "splinterburst_unlock",
	  "label": "Splinterburst contribution",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Activate to spend all held Bark for radial damage.",
	  "detail": "Provisional CE03 tuning. Deals 1 damage per actual Bark consumed within 3 m. Six-second cooldown. Expenditure cannot activate Bark break or retaliation. Independent additional skill-bar action.",
	  "tuning": {
	    "cooldown_ms": 6000,
	    "radius_m": 3.0,
	    "damage_per_bark": 1.0
	  },
	  "fixed": 1,
	  "grants": [
	    "splinterburst"
	  ],
	  "active": true
	},

	# CE03 Vital — values and units are the authoring authority.
	"verdant_reserve": {
	  "title": "Verdant Reserve",
	  "family": "vital",
	  "scopes": ["Core", "Form", "Catalyst"],
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "New capacity investment benefits every functioning self-generated Vital source, so a stronger other slot cannot erase it",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "growth_hp",
	  "label": "Verdant Reserve contribution",
	  "unit": "capacity_hp",
	  "limit": 4,
	  "description": "Vital Bloom investment adds +%s personal Vital capacity.",
	  "detail": "Provisional CE03 tuning. New capacity investment benefits every functioning self-generated Vital source, so a stronger other slot cannot erase it. Native grants still resolve strongest, never add together.",
	  "tuning": {},
	  "values": [
	    4,
	    6,
	    8,
	    10
	  ]
	},
	"deep_renewal": {
	  "title": "Deep Renewal",
	  "family": "vital",
	  "scopes": ["Core", "Form", "Catalyst"],
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "New regeneration investment benefits functioning self-generated Vital sources",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "renewal_hp_s",
	  "label": "Deep Renewal contribution",
	  "unit": "regen_hp",
	  "limit": 4,
	  "description": "Vital Bloom investment adds +%s HP/s regeneration.",
	  "detail": "Provisional CE03 tuning. New regeneration investment benefits functioning self-generated Vital sources. Existing Greening Chime stays Catalyst-specific.",
	  "tuning": {},
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"blooming_strength": {
	  "title": "Blooming Strength",
	  "family": "vital",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Only the caster receives this native damage preparation, while that Bloom grant lasts",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "bloom_attack_hp",
	  "label": "Blooming Strength contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Your Vital Bloom grants +%s primary basic-attack damage.",
	  "detail": "Provisional CE03 tuning. Only the caster receives this native damage preparation, while that Bloom grant lasts. First eligible direct target per ordinary attack only.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"growing_edge": {
	  "title": "Growing Edge",
	  "family": "vital",
	  "scopes": ["Core", "Form", "Catalyst"],
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "All functioning self-generated Vital sources include this investment; grants retain strongest-source resolution",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "vital"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "vital_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "growth_hp",
	  "label": "Growing Edge contribution",
	  "unit": "capacity_hp",
	  "limit": 4,
	  "description": "Vital Form investment adds +%s personal Vital capacity.",
	  "detail": "Provisional CE03 tuning. All functioning self-generated Vital sources include this investment; grants retain strongest-source resolution.",
	  "tuning": {},
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"sustaining_strikes": {
	  "title": "Sustaining Strikes",
	  "family": "vital",
	  "scopes": ["Core", "Form", "Catalyst"],
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "All functioning self-generated Vital sources include this regeneration investment",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "vital"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "vital_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "renewal_hp_s",
	  "label": "Sustaining Strikes contribution",
	  "unit": "regen_hp",
	  "limit": 4,
	  "description": "Vital Form investment adds +%s HP/s regeneration.",
	  "detail": "Provisional CE03 tuning. All functioning self-generated Vital sources include this regeneration investment. Does not heal immediately.",
	  "tuning": {},
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"flourishing_assault": {
	  "title": "Flourishing Assault",
	  "family": "vital",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Uses resolved current maximum capacity, including real Vital growth",
	  "consumer": [
	    "res://vital_combat.gd",
	    "ordinary_bonus"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "vital"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "vital_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "max_hp_basis_points",
	  "label": "Flourishing Assault contribution",
	  "unit": "basis_points",
	  "limit": 4,
	  "description": "Primary basic hits gain damage equal to %s%% of effective Max HP.",
	  "detail": "Provisional CE03 tuning. Uses resolved current maximum capacity, including real Vital growth. Never spends HP. Once per ordinary attack on its first eligible direct target.",
	  "tuning": {},
	  "values": [
	    50,
	    75,
	    100,
	    125
	  ]
	},
	"persistent_growth": {
	  "title": "Persistent Growth",
	  "family": "vital",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Extends only actual Form-generated Vitality, with ordinary expiry clamping",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "form",
	          "primary_affinity": "vital"
	        }
	      },
	      {
	        "capability": {
	          "producer": "form",
	          "id": "vital_strikes",
	          "slot": "form"
	        }
	      }
	    ]
	  },
	  "parameter": "duration_bonus_ms",
	  "label": "Persistent Growth contribution",
	  "unit": "ms",
	  "limit": 4,
	  "description": "Vital Form grants last +%s s.",
	  "detail": "Provisional CE03 tuning. Extends only actual Form-generated Vitality, with ordinary expiry clamping.",
	  "tuning": {},
	  "values": [
	    250,
	    400,
	    550,
	    700
	  ]
	},
	"verdant_conduit": {
	  "title": "Verdant Conduit",
	  "family": "vital",
	  "scopes": ["Core", "Form", "Catalyst"],
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Benefits functioning self-generated Vital sources; no unconditional additive grant stacking",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
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
	              "id": "self_vitality"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "radial_vitality"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_vitality"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_vitality"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "growth_hp",
	  "label": "Verdant Conduit contribution",
	  "unit": "capacity_hp",
	  "limit": 4,
	  "description": "Vital Catalyst investment adds +%s personal Vital capacity.",
	  "detail": "Provisional CE03 tuning. Benefits functioning self-generated Vital sources; no unconditional additive grant stacking.",
	  "tuning": {},
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"renewed_vigor": {
	  "title": "Renewed Vigor",
	  "family": "vital",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Lasts 2 seconds while Vitality remains active",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
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
	              "id": "self_vitality"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "radial_vitality"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_vitality"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_vitality"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "vigor_attack_hp",
	  "label": "Renewed Vigor contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Class responses that grant you Vitality prepare +%s basic-hit damage.",
	  "detail": "Provisional CE03 tuning. Lasts 2 seconds while Vitality remains active. First primary target per ordinary attack. No extra damage or healing-type Catalyst event.",
	  "tuning": {
	    "duration_ms": 2000
	  },
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"living_reserves": {
	  "title": "Living Reserves",
	  "family": "vital",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Counted once alongside source investments",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "vital"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "vital_strikes",
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
	              "primary_affinity": "vital"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "self_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_vitality"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "growth_all_hp",
	  "label": "Living Reserves contribution",
	  "unit": "capacity_hp",
	  "limit": 4,
	  "description": "Your Vital grants gain +%s maximum-health capacity.",
	  "detail": "Provisional CE03 tuning. Counted once alongside source investments. Strongest active grant determines capacity; increasing capacity never heals.",
	  "tuning": {},
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"unyielding_growth": {
	  "title": "Unyielding Growth",
	  "family": "vital",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Maintains native source identity and recipient life/floor expiry",
	  "consumer": [
	    "res://vital_combat.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "vital"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "vital_strikes",
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
	              "primary_affinity": "vital"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "self_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_vitality"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "persistence_ms",
	  "label": "Unyielding Growth contribution",
	  "unit": "ms",
	  "limit": 4,
	  "description": "Your Vital grants last +%s s.",
	  "detail": "Provisional CE03 tuning. Maintains native source identity and recipient life/floor expiry. No permanent health or extra instant healing.",
	  "tuning": {},
	  "values": [
	    250,
	    400,
	    550,
	    700
	  ]
	},
	"harvest": {
	  "title": "Harvest",
	  "family": "vital",
	  "scope": "affinity",
	  "policy": "unique",
	  "trigger": "Each launched ordinary attack spends up to 2 filled bonus HP for 2 damage per HP actually spent",
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "form",
	              "primary_affinity": "vital"
	            }
	          },
	          {
	            "capability": {
	              "producer": "form",
	              "id": "vital_strikes",
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
	              "primary_affinity": "vital"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "self_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_vitality"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_vitality"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "harvest_unlock",
	  "label": "Harvest contribution",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Toggle basic attacks to spend filled Vital bonus HP for damage.",
	  "detail": "Provisional CE03 tuning. Each launched ordinary attack spends up to 2 filled bonus HP for 2 damage per HP actually spent. Once per attack, first eligible primary contact only. Normal HP and maximum capacity are unchanged. Empty reserves suspend the bonus while leaving the toggle on.",
	  "tuning": {
	    "toggle_interval_ms": 250,
	    "spend_hp": 2.0,
	    "damage_per_hp": 2.0
	  },
	  "fixed": 1,
	  "grants": [
	    "harvest"
	  ],
	  "active": true
	},

	# CE04 Storm — values and units are the authoring authority.
	"extended_circuit": {
	  "title": "Extended Circuit",
	  "family": "storm",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Each normal chain target is hit once",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "extra_jumps",
	  "label": "Extended Circuit contribution",
	  "unit": "targets",
	  "limit": 4,
	  "description": "Chain Spark gains +%s chain targets.",
	  "detail": "Provisional CE04 tuning. Each normal chain target is hit once. Unused targets can support separately acquired Grounded Current.",
	  "tuning": {},
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"long_arc": {
	  "title": "Long Arc",
	  "family": "storm",
	  "scope": "core",
	  "policy": "stackable",
	  "trigger": "Changes per-jump reach, not its initial weapon delivery",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "jump_range_cm",
	  "label": "Long Arc contribution",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Chain Spark jumps +%s m farther.",
	  "detail": "Provisional CE04 tuning. Changes per-jump reach, not its initial weapon delivery.",
	  "tuning": {},
	  "values": [
	    25,
	    40,
	    55,
	    70
	  ]
	},
	"live_wire": {
	  "title": "Live Wire",
	  "family": "storm",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Only the existing Arcing Strikes response; no extra ordinary hit or response",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "arc",
	  "label": "Live Wire contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Basic-attack electrical arcs gain +%s damage.",
	  "detail": "Provisional CE04 tuning. Only the existing Arcing Strikes response; no extra ordinary hit or response.",
	  "tuning": {},
	  "values": [
	    2,
	    3,
	    4,
	    5
	  ]
	},
	"ionized_rhythm": {
	  "title": "Ionized Rhythm",
	  "family": "storm",
	  "scope": "form",
	  "policy": "stackable",
	  "trigger": "Lasts 2 seconds after actual electrical damage",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
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
	  },
	  "parameter": "tempo_percent",
	  "label": "Ionized Rhythm contribution",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Successful Arcing Strikes grant +%s%% basic attack speed.",
	  "detail": "Provisional CE04 tuning. Lasts 2 seconds after actual electrical damage. Reapplication refreshes, does not multiply the bonus. Existing attack interval floor applies.",
	  "tuning": {
	    "duration_ms": 2000
	  },
	  "values": [
	    4,
	    6,
	    8,
	    10
	  ]
	},
	"charged_casting": {
	  "title": "Charged Casting",
	  "family": "storm",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Applies to existing offensive discharges, actual-block/landing bursts and granted recipient charges",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "storm"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "discharge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "radial_discharge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_charge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_discharge"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "catalyst_damage_hp",
	  "label": "Charged Casting contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "Mapped class lightning gains +%s damage.",
	  "detail": "Provisional CE04 tuning. Applies to existing offensive discharges, actual-block/landing bursts and granted recipient charges.",
	  "tuning": {},
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"relay_pulse": {
	  "title": "Relay Pulse",
	  "family": "storm",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "Adds unique chain contacts to existing discharge/charge responses",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "storm"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "discharge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_charge"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "extra_jumps",
	  "label": "Relay Pulse contribution",
	  "unit": "targets",
	  "limit": 4,
	  "description": "Class discharges and recipient charges reach +%s targets.",
	  "detail": "Provisional CE04 tuning. Adds unique chain contacts to existing discharge/charge responses. Does not invent a new Catalyst trigger.",
	  "tuning": {},
	  "values": [
	    1,
	    2,
	    3,
	    4
	  ]
	},
	"spellcharge": {
	  "title": "Spellcharge",
	  "family": "storm",
	  "scope": "catalyst",
	  "policy": "stackable",
	  "trigger": "After a real mapped response, store one source-owned preparation for 4 seconds",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "all": [
	      {
	        "plant": {
	          "slot": "catalyst",
	          "primary_affinity": "storm"
	        }
	      },
	      {
	        "any": [
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "discharge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "radial_discharge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "recipient_charge"
	            }
	          },
	          {
	            "capability": {
	              "producer": "catalyst",
	              "id": "landing_discharge"
	            }
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "prepared_discharge_hp",
	  "label": "Spellcharge contribution",
	  "unit": "hp",
	  "limit": 4,
	  "description": "A class response prepares +%s damage for the next discharge.",
	  "detail": "Provisional CE04 tuning. After a real mapped response, store one source-owned preparation for 4 seconds. The next electrical response captures it once; its own bonus cannot prepare another response.",
	  "tuning": {
	    "duration_ms": 4000
	  },
	  "values": [
	    3,
	    5,
	    7,
	    9
	  ]
	},
	"grounded_current": {
	  "title": "Grounded Current",
	  "family": "storm",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Uses actual unused normal jump opportunities and their falloff",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "catalyst",
	              "primary_affinity": "storm"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "discharge"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_discharge"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_charge"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_discharge"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "unused_percent",
	  "label": "Grounded Current contribution",
	  "unit": "percent",
	  "limit": 4,
	  "description": "Convert %s%% of unused chain damage into primary-target damage.",
	  "detail": "Provisional CE04 tuning. Uses actual unused normal jump opportunities and their falloff. Adds to the original native hit, rather than creating another proc. Useful against one enemy.",
	  "tuning": {},
	  "values": [
	    25,
	    40,
	    55,
	    70
	  ]
	},
	"conductive_reach": {
	  "title": "Conductive Reach",
	  "family": "storm",
	  "scope": "affinity",
	  "policy": "stackable",
	  "trigger": "Applies through functioning Core, Form and compatible Catalyst chain sources",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "on_event"
	  ],
	  "requires": {
	    "any": [
	      {
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
	      },
	      {
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
	      },
	      {
	        "all": [
	          {
	            "plant": {
	              "slot": "catalyst",
	              "primary_affinity": "storm"
	            }
	          },
	          {
	            "any": [
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "discharge"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "radial_discharge"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "recipient_charge"
	                }
	              },
	              {
	                "capability": {
	                  "producer": "catalyst",
	                  "id": "landing_discharge"
	                }
	              }
	            ]
	          }
	        ]
	      }
	    ]
	  },
	  "parameter": "jump_range_cm",
	  "label": "Conductive Reach contribution",
	  "unit": "cm",
	  "limit": 4,
	  "description": "Storm chain jumps reach +%s m farther.",
	  "detail": "Provisional CE04 tuning. Applies through functioning Core, Form and compatible Catalyst chain sources.",
	  "tuning": {},
	  "values": [
	    20,
	    30,
	    40,
	    50
	  ]
	},
	"conductor": {
	  "title": "Conductor",
	  "family": "storm",
	  "scope": "affinity",
	  "policy": "unique",
	  "trigger": "One 45%-strength nonrecursive fork per normal node can hit another unvisited enemy",
	  "consumer": [
	    "res://storm_affinity.gd",
	    "discharge"
	  ],
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
	  },
	  "parameter": "conductor_unlock",
	  "label": "Conductor contribution",
	  "unit": "unlock",
	  "limit": 1,
	  "description": "Chain Spark forks and returns a reduced strike to its first target.",
	  "detail": "Provisional CE04 tuning. One 45%-strength nonrecursive fork per normal node can hit another unvisited enemy. One return deals 35% of the starting discharge damage (before Grounded Current) to its original surviving spawn within jump reach, including in solo combat.",
	  "tuning": {
	    "forks_per_node": 1,
	    "fork_percent": 45,
	    "return_percent": 35
	  },
	  "fixed": 1,
	  "grants": [
	    "conductor"
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
	var number := str(value) if definition.unit in ["targets","hp","healing_hp","capacity_hp","regen_hp","pressure","bark","fragments","penetrations","stacks","percent","unlock"] else ("%.3f" % (value / 1000.0)).rstrip("0").trim_suffix(".")
	if definition.unit == "basis_points": number = ("%.2f" % (value/100.0)).rstrip("0").trim_suffix(".")
	if definition.unit == "cm": number = ("%.2f" % (value / 100.0)).rstrip("0").trim_suffix(".")
	return text % number


static func contribution_label(definition: Dictionary) -> String:
	if definition.get("family", "") != "": return str(definition.get("label","Contribution"))
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
	if definition.unit == "targets": return "+%d chain targets" % value
	if definition.unit == "basis_points": return "+%.2f%% of Max HP as damage" % (value/100.0)
	if definition.unit == "capacity_hp": return "+%d Max HP" % value
	if definition.unit == "regen_hp": return "+%d HP/s" % value
	if definition.unit == "bark": return "+%d Bark" % value
	if definition.unit == "fragments": return "+%d fragments" % value
	if definition.unit == "penetrations": return "+%d extra targets per fragment" % value
	if definition.unit == "pressure": return "+%d Saturation" % value
	if definition.unit == "healing_hp": return "+%d HP healing" % value
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

static func scope_label(definition: Dictionary) -> String:
	return " · ".join(PackedStringArray(definition.scopes)) if definition.has("scopes") else str(definition.scope).capitalize()
