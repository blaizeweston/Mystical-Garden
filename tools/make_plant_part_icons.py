from pathlib import Path
import json
p=Path(__file__).resolve().parent.parent
data=json.loads((p/'tools/plant_part_icons.json').read_text(encoding='utf-8'))
out=p/'assets/ui/parts';out.mkdir(parents=True,exist_ok=True)
colors=['#c4a66a','#bdd665','#ae9bc7','#df924d','#a4b66b','#80c7c4','#b57077','#b4c8b5','#a4c6e4','#b0a7dc','#d8bc8c','#9888b4','#e1c96c','#a993c1','#d2c7a3','#a2ccde','#b99d72','#b3c281','#b1c9c2','#a6aea0','#8dcac7','#c5b4c8','#d4a7ab','#c9b474']
paths=[
 'M21 48 Q29 30 44 13 L38 31 L50 27 L39 40 L43 48 L30 43 L26 53 Z',
 'M19 47 Q14 33 22 18 Q28 26 27 41 Q30 19 35 15 Q39 30 35 43 Q45 25 49 28 Q49 45 39 50 L23 51 Z',
 'M12 30 Q16 11 34 13 Q50 14 52 31 Q39 39 12 30 Z M27 34 L36 35 L39 49 Q31 55 25 49 Z',
 'M27 52 L32 15 L39 11 L37 22 L47 17 L40 32 L51 27 L40 42 L30 49 Z',
 'M21 50 Q44 48 42 32 Q38 20 27 28 Q19 36 31 39 Q41 39 37 30 L42 23 Q52 32 43 46 Q35 57 21 54 Z',
 'M14 29 Q20 9 38 16 Q48 19 51 32 Q34 40 14 29 Z M29 34 L36 35 L34 51 L25 51 Z',
 'M19 52 L32 13 L38 12 L35 27 L49 22 L35 37 L43 44 L30 43 L25 54 Z',
 'M27 53 L30 17 L39 10 L37 25 L48 20 L41 34 L51 31 L40 44 L34 51 Z',
 'M24 53 L27 17 Q30 8 34 15 L33 28 L40 15 L45 18 L34 39 L32 54 Z',
 'M32 51 Q10 42 18 24 Q26 27 30 36 Q25 19 33 11 Q43 21 37 36 Q45 25 51 28 Q53 46 32 51 Z',
 'M31 51 Q13 45 15 28 Q27 25 31 34 Q24 19 34 12 Q43 22 37 33 Q51 20 54 32 Q48 48 31 51 Z',
 'M22 50 Q43 38 28 26 Q20 16 34 11 L43 14 Q34 17 38 25 Q56 43 30 54 Z',
 'M24 51 L27 28 L22 28 L34 10 L44 28 L38 28 L40 51 Z',
 'M18 51 Q31 38 23 25 L30 12 L36 17 L32 30 Q43 31 46 42 L40 53 L34 48 L35 39 L28 40 L25 54 Z',
 'M21 43 L17 28 L28 14 L43 17 L50 31 L44 47 L31 53 Z',
 'M22 43 Q14 30 32 14 Q50 31 45 43 L38 39 L34 48 L28 40 Z',
 'M20 47 L24 17 Q35 10 42 19 L40 45 Q31 54 20 47 Z',
 'M18 49 Q45 49 40 31 Q36 16 25 26 Q19 35 29 35 L32 42 Q15 45 15 31 Q18 12 36 18 Q56 32 43 49 L24 54 Z',
 'M19 48 Q12 18 47 13 Q50 48 19 48 Z',
 'M15 47 L21 19 L26 20 L25 40 L33 13 L38 15 L34 41 L46 21 L50 25 L42 49 L28 53 Z',
 'M17 23 Q30 32 47 23 L44 39 L36 44 L37 50 L43 52 L22 52 L27 49 L27 43 L20 37 Z',
 'M19 46 Q10 23 31 15 Q50 14 49 37 L38 46 L34 51 L27 45 Z M27 34 Q32 23 39 30 L36 40 L30 42 Z',
 'M18 43 L21 22 L31 15 L45 21 L49 39 L38 49 L25 51 Z',
 'M17 39 Q20 17 36 16 Q52 21 45 40 Q35 56 21 49 L18 44 L25 40 Q36 44 37 32 Q34 23 28 29 L27 37 Z'
]
for entry in data:
 d=entry['definition'];source=entry['source'];rare=d['id'].startswith('rare:');color=colors[source]
 name=d['id'].replace(':','_')+'.svg'
 # Rounded specimen shading, organic outlines and hand-drawn veins remain legible at 44 px.
 ornament='<path d="M17 49 Q25 26 42 15 M25 38 L18 30 M30 31 L42 28 M34 22 L30 18" fill="none" stroke="#f1e0b5" stroke-opacity=".45" stroke-width="1.2"/>'
 if rare:ornament+='<path d="M34 17 L43 28 L37 42 L27 36 L26 24 Z" fill="#e6d9ae" fill-opacity=".55" stroke="#f9edca" stroke-width="1.5"/><path d="M34 17 L32 30 L37 42 M26 24 L43 28 L27 36" fill="none" stroke="#625b54" stroke-width="1"/>'
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><defs><radialGradient id="shade"><stop stop-color="{color}"/><stop offset="1" stop-color="#444a36"/></radialGradient></defs><ellipse cx="33" cy="53" rx="21" ry="4" fill="#090e0b" opacity=".5"/><g transform="rotate({-9 if rare else 3},32,32)"><path d="{paths[source]}" fill="url(#shade)" fill-rule="evenodd" stroke="#161d16" stroke-width="3" stroke-linejoin="round"/>{ornament}</g></svg>'
 (out/name).write_text(svg,encoding='utf-8')
print(f'Generated {len(data)} distinct plant component icons')
