import os
import shutil
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('w:top', top), ('w:bottom', bottom), ('w:left', left), ('w:right', right)]:
        node = OxmlElement(m)
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def set_cell_left_border(cell, color_hex="F59E0B", size=24):
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = parse_xml(f'''
        <w:tcBorders {nsdecls("w")}>
            <w:top w:val="none"/>
            <w:left w:val="single" w:sz="{size}" w:space="0" w:color="{color_hex}"/>
            <w:bottom w:val="none"/>
            <w:right w:val="none"/>
        </w:tcBorders>
    ''')
    tcPr.append(tcBorders)

def set_table_borders(table, color="D2D6DC", sz="4"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(f'''
        <w:tblBorders {nsdecls("w")}>
            <w:top w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:left w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:bottom w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:right w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:insideH w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
            <w:insideV w:val="single" w:sz="{sz}" w:space="0" w:color="{color}"/>
        </w:tblBorders>
    ''')
    tblPr.append(borders)

def build_pitch_proposal_doc(output_path, logo_path):
    doc = Document()

    # 1. Page Margins (0.85 in for clean spacing)
    for section in doc.sections:
        section.top_margin = Inches(0.85)
        section.bottom_margin = Inches(0.85)
        section.left_margin = Inches(0.85)
        section.right_margin = Inches(0.85)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)

    # Styles setup
    style_normal = doc.styles['Normal']
    style_normal.font.name = 'Calibri'
    style_normal.font.size = Pt(10)
    style_normal.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    style_normal.paragraph_format.line_spacing = 1.15
    style_normal.paragraph_format.space_after = Pt(5)

    # Brand Colors
    NAVY = RGBColor(0x1B, 0x36, 0x5D)
    HINOPT_GOLD = RGBColor(0xD9, 0x77, 0x06)  # Warm Gold matching logo
    DARK_BLUE = RGBColor(0x1E, 0x3A, 0x8A)
    SLATE = RGBColor(0x4A, 0x55, 0x68)
    DARK = RGBColor(0x2D, 0x37, 0x48)

    # Top Header Table with Logo and Title
    header_table = doc.add_table(rows=1, cols=2)
    header_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    header_table.autofit = False

    c_logo, c_text = header_table.rows[0].cells[0], header_table.rows[0].cells[1]
    c_logo.width = Inches(1.8)
    c_text.width = Inches(5.0)
    set_cell_margins(c_logo, top=40, bottom=40, left=40, right=80)
    set_cell_margins(c_text, top=40, bottom=40, left=80, right=40)
    c_logo.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
    c_text.vertical_alignment = WD_ALIGN_VERTICAL.CENTER

    # Logo
    if os.path.exists(logo_path):
        p_logo = c_logo.paragraphs[0]
        p_logo.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p_logo.paragraph_format.space_after = Pt(0)
        r_logo = p_logo.add_run()
        r_logo.add_picture(logo_path, width=Inches(1.5))
    else:
        p_logo = c_logo.paragraphs[0]
        r = p_logo.add_run("HINOPT")
        r.font.bold = True
        r.font.size = Pt(20)
        r.font.color.rgb = HINOPT_GOLD

    # Title & Subtitle in right cell
    p_title = c_text.paragraphs[0]
    p_title.paragraph_format.space_before = Pt(0)
    p_title.paragraph_format.space_after = Pt(3)
    r_title = p_title.add_run("Strategic Technology Partnership Proposal")
    r_title.font.name = 'Calibri'
    r_title.font.size = Pt(17)
    r_title.font.bold = True
    r_title.font.color.rgb = NAVY

    p_sub = c_text.add_paragraph()
    p_sub.paragraph_format.space_before = Pt(0)
    p_sub.paragraph_format.space_after = Pt(2)
    r_sub = p_sub.add_run("Powering Admobitics Auto-Rickshaw Advertising with HINOPT Technology")
    r_sub.font.name = 'Calibri'
    r_sub.font.size = Pt(11)
    r_sub.font.color.rgb = HINOPT_GOLD
    r_sub.font.bold = True

    p_doc_id = c_text.add_paragraph()
    p_doc_id.paragraph_format.space_before = Pt(0)
    p_doc_id.paragraph_format.space_after = Pt(0)
    r_id = p_doc_id.add_run("Doc Ref: HINOPT-PROP-2026-ADM01 | hinopt.com")
    r_id.font.size = Pt(8.5)
    r_id.font.color.rgb = SLATE

    set_table_borders(header_table, color="E2E8F0", sz="4")

    # Metadata Grid
    doc.add_paragraph().paragraph_format.space_before = Pt(4)
    meta_table = doc.add_table(rows=3, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_table.autofit = False

    meta_rows = [
        [("Prepared by:", "HINOPT Technologies (Engineering & Platform Division)"),
         ("Prepared for:", "Admobitics Leadership Team (In-Auto Media Fleet)")],
        [("Official Website:", "https://hinopt.com"),
         ("Client Website:", "https://admobitics.vercel.app")],
        [("Operational Hubs:", "Hyderabad & Visakhapatnam, India"),
         ("Agreement Class:", "Confidential — Strategic Partnership & Co-Growth")]
    ]

    for r_idx, row_data in enumerate(meta_rows):
        row = meta_table.rows[r_idx]
        for c_idx, (k, v) in enumerate(row_data):
            cell = row.cells[c_idx]
            cell.width = Inches(3.4)
            set_cell_background(cell, "F8FAFC" if (r_idx + c_idx) % 2 == 0 else "F1F5F9")
            set_cell_margins(cell, top=50, bottom=50, left=80, right=80)
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            rk = p.add_run(k + " ")
            rk.font.bold = True
            rk.font.size = Pt(9)
            rk.font.color.rgb = SLATE
            rv = p.add_run(v)
            rv.font.size = Pt(9)
            rv.font.bold = (c_idx == 0 and r_idx == 0) or (c_idx == 1 and r_idx == 0)
            rv.font.color.rgb = NAVY if rv.font.bold else DARK

    set_table_borders(meta_table, color="CBD5E1", sz="4")

    # Helper function for Section Headings
    def add_sec_heading(title, number):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(12)
        h.paragraph_format.space_after = Pt(4)
        h.paragraph_format.keep_with_next = True
        r_num = h.add_run(f"{number}. ")
        r_num.font.name = 'Calibri'
        r_num.font.size = Pt(13)
        r_num.font.bold = True
        r_num.font.color.rgb = HINOPT_GOLD
        r = h.add_run(title)
        r.font.name = 'Calibri'
        r.font.size = Pt(13)
        r.font.bold = True
        r.font.color.rgb = NAVY

    # --- SECTION 1: EXECUTIVE SUMMARY ---
    add_sec_heading("Executive Summary", 1)
    
    p = doc.add_paragraph()
    r = p.add_run("Admobitics ")
    r.font.bold = True
    p.add_run("is pioneering Hyderabad’s premier in-auto digital advertising network across major commercial, IT, and transit corridors (HITEC City, Madhapur, Gachibowli, Jubilee Hills, and Secunderabad).")

    p = doc.add_paragraph()
    p.add_run("To ensure Admobitics operates on a reliable, industrial-grade technology platform without burning capital on custom software development or monthly vendor SaaS fees, ")
    r = p.add_run("HINOPT Technologies proposes a 2-Year Strategic Partnership")
    r.font.bold = True
    p.add_run(":")

    bullets_s1 = [
        ("Complete Software Platform 100% Free (2 Years): ", "HINOPT provides the native Android Display Kiosk Player, Cloud Infrastructure, and the Admobitics Operations Management Portal at zero license cost (₹0)."),
        ("Mutual Growth Through Co-Branding: ", "As fellow startups building the future together, Admobitics includes 1 companion slot (15 seconds) in the standard loop across screens to showcase HINOPT branding and future tech products, driving brand visibility for both companies."),
        ("100% Ad Revenue Retained by Admobitics: ", "Admobitics keeps 100% of all advertiser revenues. HINOPT charges zero platform commission, zero revenue cut, and zero setup fees."),
        ("Long-Term Maintenance Predictability: ", "From Year 3 onwards, Admobitics contributes a nominal, subsidized maintenance fee of just ₹100 per active screen / month to assist with raw cloud server hosting, while keeping the companion slot active.")
    ]
    for b_title, b_desc in bullets_s1:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_after = Pt(3)
        r_b = bp.add_run(b_title)
        r_b.font.bold = True
        r_b.font.color.rgb = NAVY
        bp.add_run(b_desc)

    # --- SECTION 2: HINOPT CREDENTIALS & ENGINEERING PROOF ---
    add_sec_heading("HINOPT Technology Credentials & Engineering Proof", 2)
    
    p = doc.add_paragraph()
    p.add_run("HINOPT Technologies (")
    r_site = p.add_run("hinopt.com")
    r_site.font.bold = True
    r_site.font.color.rgb = HINOPT_GOLD
    p.add_run(") is an established digital product engineering and enterprise technology solutions company headquartered in Visakhapatnam and Hyderabad, India. We architect and deploy high-performance websites, resilient offline-first operational systems, scalable multi-tenant SaaS, and autonomous workflow automations.")

    # Callout Table for Proof Points
    proof_tbl = doc.add_table(rows=1, cols=1)
    proof_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    proof_tbl.autofit = False
    p_cell = proof_tbl.rows[0].cells[0]
    p_cell.width = Inches(6.8)
    set_cell_background(p_cell, "FFFBEB")  # Warm light amber/gold background
    set_cell_left_border(p_cell, color_hex="D97706", size=26)
    set_cell_margins(p_cell, top=80, bottom=80, left=120, right=120)
    
    cp = p_cell.paragraphs[0]
    cp.paragraph_format.space_after = Pt(2)
    cp_title = cp.add_run("Verified Company Proof & Production Track Record:\n")
    cp_title.font.bold = True
    cp_title.font.size = Pt(10)
    cp_title.font.color.rgb = HINOPT_GOLD

    proof_points = [
        ("Official Corporate Portal: ", "hinopt.com | Direct Inquiries: hello@hinopt.com | +91 9390952712"),
        ("Admobitics Web Platform: ", "Designed, engineered, and deployed Admobitics' primary public web portal (admobitics.vercel.app), proving direct familiarity with your brand identity and media mission."),
        ("Enterprise Offline-First Systems: ", "Built production-grade dining & store operational apps (Dream Desserts QR Ordering, Cafe Coffee Delite Contactless Dining, Hinopt Restaurant POS & Kitchen Display)."),
        ("High-Concurrency Student Housing: ", "Architected Hinopt Hostel resident companion and student operations platform."),
        ("Hardware-Accelerated Engineering: ", "Specialized in Android kiosk LockTask mode, offline SQLite caching, and zero-touch ignition boot recovery specifically tested for TPC 151TCT digital signage panels.")
    ]
    for k, v in proof_points:
        p_pt = p_cell.add_paragraph()
        p_pt.paragraph_format.space_after = Pt(2)
        r_k = p_pt.add_run("✔ " + k)
        r_k.font.bold = True
        r_k.font.size = Pt(9)
        r_k.font.color.rgb = NAVY
        r_v = p_pt.add_run(v)
        r_v.font.size = Pt(9)

    # --- SECTION 3: THE AUTO-RICKSHAW CHALLENGE & HINOPT SOLUTIONS ---
    add_sec_heading("The Auto-Rickshaw Tech Challenge (And How HINOPT Solves It)", 3)
    p = doc.add_paragraph()
    p.add_run("Running digital screens inside moving auto-rickshaws in Hyderabad presents unique operational challenges that crash standard consumer video players. HINOPT was engineered specifically to solve these real-world conditions:")

    challenge_table = doc.add_table(rows=5, cols=3)
    challenge_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    challenge_table.autofit = False

    col_widths = [Inches(1.8), Inches(2.2), Inches(2.8)]
    headers = ["The Operational Challenge", "The Risk to Admobitics", "How HINOPT Solves It"]

    hdr_row = challenge_table.rows[0]
    for idx, name in enumerate(headers):
        cell = hdr_row.cells[idx]
        cell.width = col_widths[idx]
        set_cell_background(cell, "1B365D")
        set_cell_margins(cell, top=80, bottom=80, left=80, right=80)
        hp = cell.paragraphs[0]
        hp.paragraph_format.space_after = Pt(0)
        hrun = hp.add_run(name)
        hrun.font.bold = True
        hrun.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        hrun.font.size = Pt(9)

    challenges_data = [
        (
            "Engine Cutoffs & Battery Drops",
            "Auto drivers shut off engines at traffic signals. Standard players crash, display error screens, or require manual reboot.",
            "Automatic Kiosk Resume: When ignition turns on, HINOPT auto-boots into Kiosk mode within 10 seconds and resumes video playback with zero manual touch."
        ),
        (
            "Cellular Dead Zones",
            "Autos traverse underpasses, flyovers, and low-connectivity zones. Streaming apps freeze or display buffering spinners.",
            "100% Offline-First Playback: All videos and schedules are cached locally on eMMC memory. Ads play continuously 24/7 with zero dependence on active internet."
        ),
        (
            "Screen Tampering",
            "Passengers or drivers tap screens, exit to YouTube, or change Android settings.",
            "Complete Kiosk Lock (LockTask): System navigation bars, home/back buttons, and settings are fully locked. Only approved ads play."
        ),
        (
            "Remote Fleet Management",
            "Updating ad campaigns manually across 10 autos requires physically plugging in USB drives in each vehicle.",
            "One-Click Cloud Sync: Admobitics uploads ad videos remotely via web portal; screens automatically pull updates in the background when connected."
        )
    ]

    for row_idx, (col1, col2, col3) in enumerate(challenges_data, start=1):
        row = challenge_table.rows[row_idx]
        bg_color = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
        for c_idx, text in enumerate([col1, col2, col3]):
            cell = row.cells[c_idx]
            cell.width = col_widths[c_idx]
            set_cell_background(cell, bg_color)
            set_cell_margins(cell, top=60, bottom=60, left=80, right=80)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.TOP
            cp = cell.paragraphs[0]
            cp.paragraph_format.space_after = Pt(0)
            
            if c_idx == 0:
                r = cp.add_run(text)
                r.font.bold = True
                r.font.size = Pt(9)
                r.font.color.rgb = NAVY
            elif c_idx == 2:
                parts = text.split(":", 1)
                if len(parts) == 2:
                    r_bold = cp.add_run(parts[0] + ":")
                    r_bold.font.bold = True
                    r_bold.font.color.rgb = DARK_BLUE
                    r_bold.font.size = Pt(9)
                    r_rest = cp.add_run(parts[1])
                    r_rest.font.size = Pt(9)
                else:
                    r = cp.add_run(text)
                    r.font.size = Pt(9)
            else:
                r = cp.add_run(text)
                r.font.size = Pt(9)

    set_table_borders(challenge_table, color="D2D6DC", sz="4")

    # --- SECTION 4: WHAT ADMOBITICS GETS ---
    add_sec_heading("What Admobitics Gets (Zero Cost, Full Ownership of Ad Revenue)", 4)

    features = [
        ("1. Admobitics Operations Web Portal: ", "A clean, modern web dashboard where your operational team can upload video creatives, configure scheduling loops, and view fleet status without technical expertise."),
        ("2. Dedicated Kiosk Player Software: ", "Built natively in Kotlin with hardware-accelerated Media3 playback to prevent panel overheating and ensure ultra-smooth 1080p display on TPC 151TCT hardware."),
        ("3. Verified Proof-of-Play (PoP) Reports: ", "The player aggregates real completed impression tallies locally, giving Admobitics verifiable reporting data to win advertiser trust across Hyderabad."),
        ("4. 100% Ad Revenue Kept by Admobitics: ", "Admobitics sells all commercial ad slots and keeps 100% of all client revenue. Zero commission or cuts taken by HINOPT."),
        ("5. Seamless Fleet Scalability: ", "Effortlessly scale from the initial 10 autos to 50, 100, or 500+ vehicles across Telangana on the same robust infrastructure.")
    ]
    for f_title, f_desc in features:
        p_f = doc.add_paragraph()
        p_f.paragraph_format.space_after = Pt(3)
        r_t = p_f.add_run(f_title)
        r_t.font.bold = True
        r_t.font.color.rgb = NAVY
        p_f.add_run(f_desc)

    # --- SECTION 5: SIMPLE TERMS OF PARTNERSHIP ---
    add_sec_heading("Simple Terms of Partnership", 5)

    terms_tbl = doc.add_table(rows=2, cols=2)
    terms_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    terms_tbl.autofit = False

    t_widths = [Inches(3.4), Inches(3.4)]

    # Headers
    p1_hdr = terms_tbl.rows[0].cells[0]
    p1_hdr.width = t_widths[0]
    set_cell_background(p1_hdr, "1E3A8A")
    set_cell_margins(p1_hdr, top=60, bottom=60, left=80, right=80)
    hp1 = p1_hdr.paragraphs[0]
    hp1.paragraph_format.space_after = Pt(0)
    r = hp1.add_run("PHASE 1: YEARS 1 & 2 (Launch & Growth)")
    r.font.bold = True
    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    r.font.size = Pt(9.5)

    p2_hdr = terms_tbl.rows[0].cells[1]
    p2_hdr.width = t_widths[1]
    set_cell_background(p2_hdr, "0F766E")
    set_cell_margins(p2_hdr, top=60, bottom=60, left=80, right=80)
    hp2 = p2_hdr.paragraphs[0]
    hp2.paragraph_format.space_after = Pt(0)
    r = hp2.add_run("PHASE 2: YEAR 3 ONWARDS (Maintenance)")
    r.font.bold = True
    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    r.font.size = Pt(9.5)

    # Phase 1 Body
    c_p1_body = terms_tbl.rows[1].cells[0]
    c_p1_body.width = t_widths[0]
    set_cell_background(c_p1_body, "F8FAFC")
    set_cell_margins(c_p1_body, top=80, bottom=80, left=80, right=80)
    c_p1_body.vertical_alignment = WD_ALIGN_VERTICAL.TOP

    p1_items = [
        ("Platform License: ", "₹0 (100% Free) for the entire 2-year duration."),
        ("Fleet Coverage: ", "Covers initial 10 autos and scales automatically as fleet expands."),
        ("Co-Marketing Support: ", "1 companion slot (15 sec) per loop reserved for HINOPT brand awareness."),
        ("Zero Overhead: ", "Admobitics pays ₹0 for software, updates, bugfixes, or maintenance.")
    ]
    for idx, (t_k, t_v) in enumerate(p1_items):
        bp = c_p1_body.paragraphs[0] if idx == 0 else c_p1_body.add_paragraph()
        bp.paragraph_format.space_after = Pt(3)
        rtk = bp.add_run("• " + t_k)
        rtk.font.bold = True
        rtk.font.size = Pt(9)
        rtk.font.color.rgb = NAVY
        rtv = bp.add_run(t_v)
        rtv.font.size = Pt(9)

    # Phase 2 Body
    c_p2_body = terms_tbl.rows[1].cells[1]
    c_p2_body.width = t_widths[1]
    set_cell_background(c_p2_body, "F0FDF4")
    set_cell_margins(c_p2_body, top=80, bottom=80, left=80, right=80)
    c_p2_body.vertical_alignment = WD_ALIGN_VERTICAL.TOP

    p2_items = [
        ("Subsidized Fee: ", "Nominal ₹100 / active screen / month to assist in covering raw cloud hosting."),
        ("Predictable Costs: ", "Fixed, transparent operational expense with zero surprise bills."),
        ("Continued Co-Marketing: ", "HINOPT maintains its single promotional slot across the fleet."),
        ("Engineering Upgrades: ", "HINOPT provides continuous Android OS compatibility and feature patches.")
    ]
    for idx, (t_k, t_v) in enumerate(p2_items):
        bp = c_p2_body.paragraphs[0] if idx == 0 else c_p2_body.add_paragraph()
        bp.paragraph_format.space_after = Pt(3)
        rtk = bp.add_run("• " + t_k)
        rtk.font.bold = True
        rtk.font.size = Pt(9)
        rtk.font.color.rgb = RGBColor(0x06, 0x5F, 0x46)
        rtv = bp.add_run(t_v)
        rtv.font.size = Pt(9)

    set_table_borders(terms_tbl, color="CBD5E1", sz="4")

    # --- SECTION 6: 7-DAY PILOT ROADMAP ---
    add_sec_heading("7-Day Pilot Onboarding Plan", 6)

    pilot_table = doc.add_table(rows=6, cols=2)
    pilot_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    pilot_table.autofit = False

    p_col_widths = [Inches(1.8), Inches(5.0)]
    p_headers = ["Timeline", "Action Item & Milestone"]

    p_hdr_row = pilot_table.rows[0]
    for idx, name in enumerate(p_headers):
        cell = p_hdr_row.cells[idx]
        cell.width = p_col_widths[idx]
        set_cell_background(cell, "1B365D")
        set_cell_margins(cell, top=60, bottom=60, left=80, right=80)
        hp = cell.paragraphs[0]
        hp.paragraph_format.space_after = Pt(0)
        hrun = hp.add_run(name)
        hrun.font.bold = True
        hrun.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        hrun.font.size = Pt(9)

    pilot_schedule = [
        ("Days 1 – 2", "Review and formalize mutual strategic partnership terms."),
        ("Day 3", "Install HINOPT Kiosk Player APK on 2 pilot autos for 48-hour road trials."),
        ("Days 4 – 5", "Verify auto-ignition boot, vibration stability, and offline playback loops."),
        ("Day 6", "Roll out APK across the remaining 8 auto-rickshaws."),
        ("Day 7", "Commercial Go-Live: Run full advertiser campaigns smoothly across all 10 screens!")
    ]

    for row_idx, (t_time, t_action) in enumerate(pilot_schedule, start=1):
        row = pilot_table.rows[row_idx]
        bg = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
        c0, c1 = row.cells[0], row.cells[1]
        c0.width = p_col_widths[0]
        c1.width = p_col_widths[1]
        set_cell_background(c0, bg)
        set_cell_background(c1, bg)
        set_cell_margins(c0, top=50, bottom=50, left=80, right=80)
        set_cell_margins(c1, top=50, bottom=50, left=80, right=80)

        p0 = c0.paragraphs[0]
        p0.paragraph_format.space_after = Pt(0)
        r0 = p0.add_run(t_time)
        r0.font.bold = True
        r0.font.size = Pt(9)
        r0.font.color.rgb = NAVY

        p1 = c1.paragraphs[0]
        p1.paragraph_format.space_after = Pt(0)
        r1 = p1.add_run(t_action)
        r1.font.size = Pt(9)

    set_table_borders(pilot_table, color="D2D6DC", sz="4")

    # --- SECTION 7: FORMAL AGREEMENT & DUAL SIGNATURE SLOTS ---
    add_sec_heading("Partnership Agreement Execution & Signatures", 7)

    p_ack = doc.add_paragraph()
    p_ack.paragraph_format.space_after = Pt(8)
    p_ack.add_run("By signing below, both parties acknowledge and accept this Strategic Technology Partnership under the mutual terms and conditions set forth above:")

    # Dual Signature Slots Table
    sign_table = doc.add_table(rows=7, cols=2)
    sign_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    sign_table.autofit = False

    s_widths = [Inches(3.4), Inches(3.4)]

    # Header Row
    sh_c0, sh_c1 = sign_table.rows[0].cells[0], sign_table.rows[0].cells[1]
    sh_c0.width, sh_c1.width = s_widths[0], s_widths[1]
    set_cell_background(sh_c0, "1B365D")
    set_cell_background(sh_c1, "1B365D")
    set_cell_margins(sh_c0, top=60, bottom=60, left=80, right=80)
    set_cell_margins(sh_c1, top=60, bottom=60, left=80, right=80)

    p_sh0 = sh_c0.paragraphs[0]
    p_sh0.paragraph_format.space_after = Pt(0)
    r = p_sh0.add_run("FOR: HINOPT TECHNOLOGIES\n(Platform & Technology Provider)")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    p_sh1 = sh_c1.paragraphs[0]
    p_sh1.paragraph_format.space_after = Pt(0)
    r = p_sh1.add_run("FOR: ADMOBITICS\n(Advertising Network & Fleet Operator)")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    # Signature Field Rows
    sig_fields = [
        ("Authorized Signature:\n\n_____________________________________",
         "Authorized Signature:\n\n_____________________________________"),
        ("Print Name: ____________________________",
         "Print Name: ____________________________"),
        ("Title / Role: Founder / Technical Director",
         "Title / Role: Managing Partner / Director"),
        ("Date Signed: ____________________________",
         "Date Signed: ____________________________"),
        ("Direct Contact: hello@hinopt.com | +91 9390952712",
         "Direct Contact: contact@admobitics.com"),
        ("Official Entity Seal / Stamp:\n\n\n[ Company Seal Space ]",
         "Official Entity Seal / Stamp:\n\n\n[ Company Seal Space ]")
    ]

    for r_idx, (f_left, f_right) in enumerate(sig_fields, start=1):
        row = sign_table.rows[r_idx]
        c0, c1 = row.cells[0], row.cells[1]
        c0.width, c1.width = s_widths[0], s_widths[1]
        bg = "FFFFFF" if r_idx % 2 == 1 else "F8FAFC"
        set_cell_background(c0, bg)
        set_cell_background(c1, bg)
        set_cell_margins(c0, top=60, bottom=60, left=80, right=80)
        set_cell_margins(c1, top=60, bottom=60, left=80, right=80)

        p0 = c0.paragraphs[0]
        p0.paragraph_format.space_after = Pt(0)
        r0 = p0.add_run(f_left)
        r0.font.size = Pt(9)
        if "Authorized Signature" in f_left or "Company Seal" in f_left:
            r0.font.bold = True

        p1 = c1.paragraphs[0]
        p1.paragraph_format.space_after = Pt(0)
        r1 = p1.add_run(f_right)
        r1.font.size = Pt(9)
        if "Authorized Signature" in f_right or "Company Seal" in f_right:
            r1.font.bold = True

    set_table_borders(sign_table, color="94A3B8", sz="6")

    # Document Footer Note
    p_footer = doc.add_paragraph()
    p_footer.paragraph_format.space_before = Pt(10)
    p_footer.paragraph_format.space_after = Pt(0)
    p_footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_foot = p_footer.add_run("HINOPT Technologies • Visakhapatnam & Hyderabad, India • Website: hinopt.com • Email: hello@hinopt.com")
    r_foot.font.size = Pt(8.5)
    r_foot.font.color.rgb = SLATE

    # Save documents
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

    # Also create a .doc file copy
    doc_path = os.path.splitext(output_path)[0] + ".doc"
    shutil.copyfile(output_path, doc_path)
    print(f"Compatible .doc copy successfully created at: {doc_path}")

if __name__ == "__main__":
    out_docx = r"d:\Advertising & Digital Signage Management Platform\docs\product\admobitics-partnership-pitch-proposal.docx"
    logo_file = r"d:\Advertising & Digital Signage Management Platform\docs\assets\hinopt-logo.png"
    build_pitch_proposal_doc(out_docx, logo_file)
