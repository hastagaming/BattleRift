class_name LoginArt
extends RefCounted

# The login artwork is an SVG kept in code, so it is drawn sharp at any screen size.
# The same drawing as a file: view the text between the triple quotes as an .svg.

const BASE_SIZE := Vector2(1280.0, 720.0)
const HERO_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#070a1c"/>
      <stop offset="0.5" stop-color="#241150"/>
      <stop offset="1" stop-color="#0d3347"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="46%" r="50%">
      <stop offset="0" stop-color="#7cfff0" stop-opacity="0.55"/>
      <stop offset="0.45" stop-color="#ff5fa8" stop-opacity="0.2"/>
      <stop offset="1" stop-color="#ff5fa8" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="rift" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ff5fa8"/>
      <stop offset="0.5" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#7cfff0"/>
    </linearGradient>
    <linearGradient id="rock" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#4b3a86"/>
      <stop offset="1" stop-color="#150f33"/>
    </linearGradient>
    <linearGradient id="hot" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffb347"/>
      <stop offset="1" stop-color="#ff4d3d"/>
    </linearGradient>
    <linearGradient id="cool" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7cfff0"/>
      <stop offset="1" stop-color="#2d7bff"/>
    </linearGradient>
    <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#070a1c" stop-opacity="0"/>
      <stop offset="1" stop-color="#070a1c" stop-opacity="0.92"/>
    </linearGradient>
  </defs>
  <rect width="1280" height="720" fill="url(#sky)"/>
  <circle cx="673" cy="85" r="2.8" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="108" cy="45" r="1.2" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="1203" cy="37" r="1.6" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="186" cy="230" r="2.8" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="502" cy="54" r="2.8" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="1168" cy="71" r="1.6" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="1203" cy="39" r="2.8" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="462" cy="31" r="1.6" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="868" cy="81" r="1.2" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="641" cy="294" r="1.6" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="1201" cy="300" r="1.6" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="209" cy="288" r="1.2" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="132" cy="324" r="1.6" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="1098" cy="226" r="2.2" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="1209" cy="240" r="2.2" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="518" cy="414" r="1.6" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="509" cy="49" r="2.2" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="1023" cy="183" r="2.8" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="1257" cy="45" r="1.2" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="866" cy="92" r="2.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="1011" cy="223" r="1.2" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="168" cy="399" r="2.2" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="727" cy="312" r="2.8" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="944" cy="43" r="1.2" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="980" cy="364" r="1.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="644" cy="339" r="2.8" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="800" cy="350" r="2.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="955" cy="189" r="1.6" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="249" cy="260" r="1.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="598" cy="74" r="1.6" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="810" cy="262" r="1.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="929" cy="213" r="2.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="891" cy="289" r="2.2" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="860" cy="191" r="2.8" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="319" cy="50" r="1.6" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="485" cy="345" r="1.6" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="1003" cy="309" r="1.6" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="587" cy="10" r="1.6" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="1104" cy="197" r="2.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="1065" cy="324" r="1.2" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="1155" cy="208" r="2.8" fill="#ffffff" fill-opacity="0.55"/>
  <circle cx="817" cy="61" r="2.8" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="830" cy="39" r="1.6" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="437" cy="233" r="1.6" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="706" cy="315" r="1.2" fill="#ffffff" fill-opacity="0.35"/>
  <circle cx="10" cy="298" r="1.6" fill="#ffffff" fill-opacity="0.8"/>
  <circle cx="640" cy="330" r="360" fill="url(#glow)"/>
  <path d="M0 520 L120 430 L230 500 L360 400 L470 490 L560 440 L560 720 L0 720 Z" fill="#120d2c"/>
  <path d="M1280 520 L1160 420 L1050 500 L930 395 L820 485 L720 440 L720 720 L1280 720 Z" fill="#120d2c"/>
  <path d="M668 -10 L628 150 L664 164 L612 300 L650 314 L596 470 L690 300 L652 288 L704 156 L672 144 L712 -10 Z" fill="#7cfff0" fill-opacity="0.16"/>
  <path d="M660 -10 L630 150 L666 164 L618 300 L654 314 L604 450 L684 300 L648 288 L696 156 L666 144 L702 -10 Z" fill="url(#rift)"/>
  <path d="M660 -10 L630 150 L666 164 L618 300 L654 314 L604 450 L684 300 L648 288 L696 156 L666 144 L702 -10 Z" fill="none" stroke="#ffffff" stroke-width="4" stroke-linejoin="round"/>
  <g>
    <ellipse cx="250" cy="560" rx="230" ry="46" fill="#6a56b8"/>
    <ellipse cx="250" cy="552" rx="230" ry="40" fill="#8d79d8"/>
    <path d="M30 566 Q250 600 470 566 L400 690 Q250 760 100 690 Z" fill="url(#rock)"/>
  </g>
  <g>
    <ellipse cx="1030" cy="580" rx="230" ry="46" fill="#6a56b8"/>
    <ellipse cx="1030" cy="572" rx="230" ry="40" fill="#8d79d8"/>
    <path d="M810 586 Q1030 620 1250 586 L1180 700 Q1030 770 880 700 Z" fill="url(#rock)"/>
  </g>
  <g>
    <circle cx="470" cy="300" r="46" fill="url(#hot)"/>
    <rect x="426" y="344" width="92" height="140" rx="46" fill="url(#hot)" transform="rotate(-12 472 414)"/>
    <rect x="500" y="340" width="150" height="34" rx="17" fill="url(#hot)" transform="rotate(-16 520 356)"/>
    <rect x="404" y="430" width="34" height="96" rx="17" fill="#c43a2f" transform="rotate(10 421 478)"/>
    <rect x="466" y="456" width="34" height="96" rx="17" fill="#c43a2f" transform="rotate(-24 483 504)"/>
    <circle cx="655" cy="334" r="24" fill="#ffd9a0"/>
  </g>
  <g>
    <circle cx="830" cy="300" r="46" fill="url(#cool)"/>
    <rect x="786" y="344" width="92" height="140" rx="46" fill="url(#cool)" transform="rotate(12 832 414)"/>
    <rect x="636" y="340" width="150" height="34" rx="17" fill="url(#cool)" transform="rotate(16 766 356)"/>
    <rect x="860" y="430" width="34" height="96" rx="17" fill="#1f56b8" transform="rotate(-10 877 478)"/>
    <rect x="800" y="456" width="34" height="96" rx="17" fill="#1f56b8" transform="rotate(24 817 504)"/>
    <circle cx="640" cy="334" r="24" fill="#c8f7ff"/>
  </g>
  <path d="M648 270 L664 322 L716 308 L678 346 L718 384 L664 376 L648 428 L632 376 L578 384 L618 346 L580 308 L632 322 Z" fill="#fff6c8"/>
  <path d="M648 300 L656 332 L686 326 L664 348 L686 372 L656 366 L648 396 L640 366 L610 372 L632 348 L610 326 L640 332 Z" fill="#ffffff"/>
  <circle cx="471" cy="432" r="2" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="526" cy="445" r="3" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="549" cy="415" r="4" fill="#ff5fa8" fill-opacity="0.75"/>
  <circle cx="482" cy="178" r="5" fill="#ff5fa8" fill-opacity="0.75"/>
  <circle cx="665" cy="555" r="4" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="493" cy="164" r="4" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="555" cy="550" r="3" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="431" cy="270" r="4" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="773" cy="616" r="2" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="572" cy="153" r="4" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="607" cy="231" r="4" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="692" cy="614" r="4" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="534" cy="259" r="3" fill="#ff5fa8" fill-opacity="0.75"/>
  <circle cx="798" cy="292" r="3" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="672" cy="424" r="2" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="824" cy="346" r="5" fill="#ff5fa8" fill-opacity="0.75"/>
  <circle cx="519" cy="412" r="5" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="598" cy="433" r="2" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="472" cy="292" r="5" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="592" cy="269" r="5" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="732" cy="61" r="5" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="596" cy="146" r="2" fill="#ff5fa8" fill-opacity="0.75"/>
  <circle cx="820" cy="264" r="5" fill="#7cfff0" fill-opacity="0.75"/>
  <circle cx="642" cy="400" r="2" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="622" cy="534" r="5" fill="#ffd166" fill-opacity="0.75"/>
  <circle cx="463" cy="222" r="3" fill="#7cfff0" fill-opacity="0.75"/>
  <rect y="360" width="1280" height="360" fill="url(#fade)"/>
</svg>
"""


static func hero_texture(target_size: Vector2) -> Texture2D:
	var scale := clampf(maxf(target_size.x / BASE_SIZE.x, target_size.y / BASE_SIZE.y), 0.5, 2.0)
	var image := Image.new()
	if image.load_svg_from_string(HERO_SVG, scale) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)