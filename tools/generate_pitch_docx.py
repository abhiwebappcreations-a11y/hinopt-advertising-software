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

def set_cell_left_border(cell, color_hex="2B6CB0", size=24):
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

def build_pitch_proposal_doc(output_path):
    doc = Document()

    # 1. Page Margins
    for section in doc.sections:
        section.top_margin = Inches(0.9)
        section.bottom_margin = Inches(0.9)
        section.left_margin = Inches(0.9)
        section.right_margin = Inches(0.9)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)

    # Styles setup
    style_normal = doc.styles['Normal']
    style_normal.font.name = 'Calibri'
    style_normal.font.size = Pt(10.5)
    style_normal.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    style_normal.paragraph_format.line_spacing = 1.15
    style_normal.paragraph_format.space_after = Pt(6)

    # Colors
    NAVY = RGBColor(0x1B, 0x36, 0x5D)
    SLATE = RGBColor(0x4A, 0x55, 0x68)
    BLUE = RGBColor(0x2B, 0x6C, 0xB0)
    DARK = RGBColor(0x2D, 0x37, 0x48)

    # Header / Title Block
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(2)
    run_title = title_p.add_run("Strategic Technology Partnership Proposal")
    run_title.font.name = 'Calibri'
    run_title.font.size = Pt(22)
    run_title.font.bold = True
    run_title.font.color.rgb = NAVY

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(0)
    sub_p.paragraph_format.space_after = Pt(14)
    run_sub = sub_p.add_run("Powering Admobitics Auto-Rickshaw Advertising with HINOPT Technology")
    run_sub.font.name = 'Calibri'
    run_sub.font.size = Pt(13)
    run_sub.font.color.rgb = BLUE
    run_sub.font.bold = True

    # Metadata Card Table
    meta_table = doc.add_table(rows=5, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_data = [
        ("Prepared by:", "HINOPT Technologies"),
        ("Prepared for:", "Admobitics Leadership Team"),
        ("Proposal Date:", "November 2026"),
        ("Location:", "Hyderabad, Telangana"),
        ("Classification:", "Confidential — Strategic Partnership Agreement")
    ]
    meta_table.autofit = False
    for i, (k, v) in enumerate(meta_data):
        row = meta_table.rows[i]
        c0, c1 = row.cells[0], row.cells[1]
        c0.width = Inches(1.8)
        c1.width = Inches(4.9)
        set_cell_background(c0, "F1F5F9")
        set_cell_background(c1, "F8FAFC")
        set_cell_margins(c0, top=60, bottom=60, left=100, right=100)
        set_cell_margins(c1, top=60, bottom=60, left=100, right=100)
        
        p0 = c0.paragraphs[0]
        p0.paragraph_format.space_after = Pt(0)
        r0 = p0.add_run(k)
        r0.font.bold = True
        r0.font.size = Pt(9.5)
        r0.font.color.rgb = SLATE

        p1 = c1.paragraphs[0]
        p1.paragraph_format.space_after = Pt(0)
        r1 = p1.add_run(v)
        r1.font.size = Pt(9.5)
        r1.font.bold = (i == 4 or i == 1)
        r1.font.color.rgb = NAVY if (i == 4 or i == 1) else DARK

    set_table_borders(meta_table, color="CBD5E1", sz="4")

    # Divider space
    p_div = doc.add_paragraph()
    p_div.paragraph_format.space_before = Pt(8)
    p_div.paragraph_format.space_after = Pt(4)

    # Helper function for Section Headings
    def add_sec_heading(title, number):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(14)
        h.paragraph_format.space_after = Pt(6)
        h.paragraph_format.keep_with_next = True
        r_num = h.add_run(f"{number}. ")
        r_num.font.name = 'Calibri'
        r_num.font.size = Pt(14)
        r_num.font.bold = True
        r_num.font.color.rgb = BLUE
        r = h.add_run(title)
        r.font.name = 'Calibri'
        r.font.size = Pt(14)
        r.font.bold = True
        r.font.color.rgb = NAVY

    # --- SECTION 1 ---
    add_sec_heading("Executive Summary", 1)
    
    p = doc.add_paragraph()
    r = p.add_run("Admobitics ")
    r.font.bold = True
    p.add_run("is building Hyderabad’s premier in-auto digital advertising network across major transit and commercial corridors (HITEC City, Madhapur, Gachibowli, Jubilee Hills, and Secunderabad).")

    p = doc.add_paragraph()
    p.add_run("To ensure Admobitics operates on a reliable, industrial-grade technology platform without burning capital on software development or monthly vendor fees, ")
    r = p.add_run("HINOPT Technologies proposes a 2-Year Strategic Partnership")
    r.font.bold = True
    p.add_run(":")

    bullets_s1 = [
        ("Complete Software Platform for 100% Free (2 Years): ", "HINOPT provides the Android Display Player Kiosk software, Cloud Infrastructure, and the Admobitics Management Portal at zero license cost (₹0)."),
        ("Mutual Growth Through Co-Branding: ", "As fellow startups growing together, Admobitics includes 1 companion slot in the loop for HINOPT branding across its auto screens, allowing both companies to build brand awareness side-by-side."),
        ("Long-Term Support: ", "From Year 3 onwards, Admobitics contributes a nominal, subsidized maintenance fee of just ₹100 per screen / month to assist with raw cloud server hosting, while keeping the co-marketing slot active.")
    ]
    for b_title, b_desc in bullets_s1:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_after = Pt(4)
        r_b = bp.add_run(b_title)
        r_b.font.bold = True
        r_b.font.color.rgb = NAVY
        bp.add_run(b_desc)

    # --- SECTION 2 ---
    add_sec_heading("The Auto-Rickshaw Tech Challenge (And How HINOPT Solves It)", 2)
    p = doc.add_paragraph()
    p.add_run("Running digital screens inside moving auto-rickshaws in Hyderabad presents unique real-world challenges that crash standard consumer video players. HINOPT was engineered specifically to address and resolve these operational risks:")

    # Table of Challenges
    challenge_table = doc.add_table(rows=5, cols=3)
    challenge_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    challenge_table.autofit = False

    col_widths = [Inches(1.8), Inches(2.2), Inches(2.7)]
    headers = ["The Operational Challenge", "The Risk to Admobitics", "How HINOPT Solves It"]

    hdr_row = challenge_table.rows[0]
    for idx, name in enumerate(headers):
        cell = hdr_row.cells[idx]
        cell.width = col_widths[idx]
        set_cell_background(cell, "1B365D")
        set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
        hp = cell.paragraphs[0]
        hp.paragraph_format.space_after = Pt(0)
        hrun = hp.add_run(name)
        hrun.font.bold = True
        hrun.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        hrun.font.size = Pt(9.5)

    challenges_data = [
        (
            "Engine Cutoffs & Battery Drops",
            "Auto drivers turn off the engine at traffic signals. Standard players crash, display error screens, or require manual restart.",
            "Automatic Kiosk Resume: When ignition restarts, HINOPT auto-boots into Kiosk mode within 10 seconds and resumes video playback with zero driver intervention."
        ),
        (
            "Cellular Dead Zones",
            "Autos travel under flyovers, underpasses, and low-reception corridors. Streaming apps freeze or show black buffering wheels.",
            "100% Offline-First Playback: All videos and schedules are cached locally on eMMC memory. Ads play continuously 24/7 with zero dependence on cellular reception."
        ),
        (
            "Screen Tampering",
            "Passengers or drivers touch the screen, exit into YouTube, or adjust Android system settings.",
            "Complete Kiosk Lock (LockTask): System navigation bars, home/back gestures, and settings are fully locked. Only approved advertiser video plays."
        ),
        (
            "Remote Fleet Management",
            "Updating ad campaigns across 10 autos manually requires physically plugging in USB drives vehicle by vehicle.",
            "One-Click Cloud Sync: Admobitics uploads ad creatives once in the web portal; connected screens pull delta updates silently in the background."
        )
    ]

    for row_idx, (col1, col2, col3) in enumerate(challenges_data, start=1):
        row = challenge_table.rows[row_idx]
        bg_color = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
        for c_idx, text in enumerate([col1, col2, col3]):
            cell = row.cells[c_idx]
            cell.width = col_widths[c_idx]
            set_cell_background(cell, bg_color)
            set_cell_margins(cell, top=80, bottom=80, left=100, right=100)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.TOP
            cp = cell.paragraphs[0]
            cp.paragraph_format.space_after = Pt(0)
            
            if c_idx == 0:
                r = cp.add_run(text)
                r.font.bold = True
                r.font.size = Pt(9.5)
                r.font.color.rgb = NAVY
            elif c_idx == 2:
                parts = text.split(":", 1)
                if len(parts) == 2:
                    r_bold = cp.add_run(parts[0] + ":")
                    r_bold.font.bold = True
                    r_bold.font.color.rgb = BLUE
                    r_bold.font.size = Pt(9.5)
                    r_rest = cp.add_run(parts[1])
                    r_rest.font.size = Pt(9.5)
                else:
                    r = cp.add_run(text)
                    r.font.size = Pt(9.5)
            else:
                r = cp.add_run(text)
                r.font.size = Pt(9.5)

    set_table_borders(challenge_table, color="D2D6DC", sz="4")

    # --- SECTION 3 ---
    add_sec_heading("What Admobitics Gets (Zero Cost, Full Ownership of Ad Revenue)", 3)

    # Callout Box for Zero Cost / Full Ownership
    callout_tbl = doc.add_table(rows=1, cols=1)
    callout_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    callout_tbl.autofit = False
    c_cell = callout_tbl.rows[0].cells[0]
    c_cell.width = Inches(6.7)
    set_cell_background(c_cell, "F0F9FF")
    set_cell_left_border(c_cell, color_hex="0284C7", size=28)
    set_cell_margins(c_cell, top=100, bottom=100, left=140, right=140)
    cp = c_cell.paragraphs[0]
    cp.paragraph_format.space_after = Pt(0)
    cr_title = cp.add_run("Key Economic Advantage for Admobitics:\n")
    cr_title.font.bold = True
    cr_title.font.size = Pt(10.5)
    cr_title.font.color.rgb = RGBColor(0x03, 0x69, 0xA1)
    cr_body = cp.add_run(
        "Admobitics sells all commercial advertising slots directly to clients and retains 100% of all ad revenues. "
        "HINOPT charges zero platform commission, zero revenue share, and zero upfront development fees."
    )
    cr_body.font.size = Pt(10)
    cr_body.font.color.rgb = DARK

    p_spacer = doc.add_paragraph()
    p_spacer.paragraph_format.space_before = Pt(4)
    p_spacer.paragraph_format.space_after = Pt(2)

    features = [
        ("1. Admobitics Operations Portal: ", "A clean, modern web dashboard where your operational team can upload video creatives, configure scheduling loops, and view fleet status without requiring technical expertise."),
        ("2. Dedicated Kiosk Player Software: ", "Built natively in Kotlin with hardware-accelerated Media3 playback to prevent panel overheating and ensure ultra-smooth 1080p display on TPC 151TCT hardware."),
        ("3. Verified Proof-of-Play (PoP) Reports: ", "The player aggregates real completed impression tallies locally, giving Admobitics verifiable reporting data to win advertiser trust across Hyderabad."),
        ("4. Seamless Future Scaling: ", "The underlying architecture effortlessly scales from the initial 10 autos to 50, 100, or 500+ vehicles across Telangana without software re-architecting.")
    ]
    for f_title, f_desc in features:
        p_f = doc.add_paragraph()
        p_f.paragraph_format.space_after = Pt(4)
        r_t = p_f.add_run(f_title)
        r_t.font.bold = True
        r_t.font.color.rgb = NAVY
        p_f.add_run(f_desc)

    # --- SECTION 4 ---
    add_sec_heading("Simple Terms of Partnership", 4)

    terms_tbl = doc.add_table(rows=2, cols=2)
    terms_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    terms_tbl.autofit = False

    t_widths = [Inches(3.35), Inches(3.35)]

    # Phase 1 Header & Content
    p1_hdr = terms_tbl.rows[0].cells[0]
    p1_hdr.width = t_widths[0]
    set_cell_background(p1_hdr, "1E3A8A")
    set_cell_margins(p1_hdr, top=80, bottom=80, left=100, right=100)
    hp1 = p1_hdr.paragraphs[0]
    hp1.paragraph_format.space_after = Pt(0)
    r = hp1.add_run("PHASE 1: YEARS 1 & 2 (Launch & Growth)")
    r.font.bold = True
    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    r.font.size = Pt(10)

    # Phase 2 Header & Content
    p2_hdr = terms_tbl.rows[0].cells[1]
    p2_hdr.width = t_widths[1]
    set_cell_background(p2_hdr, "0F766E")
    set_cell_margins(p2_hdr, top=80, bottom=80, left=100, right=100)
    hp2 = p2_hdr.paragraphs[0]
    hp2.paragraph_format.space_after = Pt(0)
    r = hp2.add_run("PHASE 2: YEAR 3 ONWARDS (Maintenance)")
    r.font.bold = True
    r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    r.font.size = Pt(10)

    # Phase 1 Body
    c_p1_body = terms_tbl.rows[1].cells[0]
    c_p1_body.width = t_widths[0]
    set_cell_background(c_p1_body, "F8FAFC")
    set_cell_margins(c_p1_body, top=100, bottom=100, left=100, right=100)
    c_p1_body.vertical_alignment = WD_ALIGN_VERTICAL.TOP

    p1_items = [
        ("Platform License: ", "₹0 (100% Free) for the entire 2-year duration."),
        ("Fleet Coverage: ", "Covers initial 10 autos and scales automatically as fleet expands."),
        ("Co-Marketing Support: ", "1 reserved companion slot (15 sec) per loop for HINOPT brand awareness."),
        ("Zero Overhead: ", "Admobitics pays ₹0 for software, updates, bugfixes, or maintenance.")
    ]
    for idx, (t_k, t_v) in enumerate(p1_items):
        bp = c_p1_body.paragraphs[0] if idx == 0 else c_p1_body.add_paragraph()
        bp.paragraph_format.space_after = Pt(3)
        rtk = bp.add_run("• " + t_k)
        rtk.font.bold = True
        rtk.font.size = Pt(9.5)
        rtk.font.color.rgb = NAVY
        rtv = bp.add_run(t_v)
        rtv.font.size = Pt(9.5)

    # Phase 2 Body
    c_p2_body = terms_tbl.rows[1].cells[1]
    c_p2_body.width = t_widths[1]
    set_cell_background(c_p2_body, "F0FDF4")
    set_cell_margins(c_p2_body, top=100, bottom=100, left=100, right=100)
    c_p2_body.vertical_alignment = WD_ALIGN_VERTICAL.TOP

    p2_items = [
        ("Subsidized Fee: ", "Nominal ₹100 / active screen / month to contribute to cloud server hosting."),
        ("Predictable Costs: ", "Fixed, transparent operational expense with zero surprise bills."),
        ("Continued Co-Marketing: ", "HINOPT maintains its single promotional slot across the network."),
        ("Engineering Upgrades: ", "HINOPT provides continuous Android compatibility and feature patches.")
    ]
    for idx, (t_k, t_v) in enumerate(p2_items):
        bp = c_p2_body.paragraphs[0] if idx == 0 else c_p2_body.add_paragraph()
        bp.paragraph_format.space_after = Pt(3)
        rtk = bp.add_run("• " + t_k)
        rtk.font.bold = True
        rtk.font.size = Pt(9.5)
        rtk.font.color.rgb = RGBColor(0x06, 0x5F, 0x46)
        rtv = bp.add_run(t_v)
        rtv.font.size = Pt(9.5)

    set_table_borders(terms_tbl, color="CBD5E1", sz="4")

    # --- SECTION 5 ---
    add_sec_heading("7-Day Pilot Onboarding Plan", 5)

    pilot_table = doc.add_table(rows=6, cols=2)
    pilot_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    pilot_table.autofit = False

    p_col_widths = [Inches(1.8), Inches(4.9)]
    p_headers = ["Timeline", "Action Item & Milestone"]

    p_hdr_row = pilot_table.rows[0]
    for idx, name in enumerate(p_headers):
        cell = p_hdr_row.cells[idx]
        cell.width = p_col_widths[idx]
        set_cell_background(cell, "1B365D")
        set_cell_margins(cell, top=80, bottom=80, left=100, right=100)
        hp = cell.paragraphs[0]
        hp.paragraph_format.space_after = Pt(0)
        hrun = hp.add_run(name)
        hrun.font.bold = True
        hrun.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        hrun.font.size = Pt(9.5)

    pilot_schedule = [
        ("Days 1 – 2", "Review and finalize mutual partnership terms."),
        ("Day 3", "Install HINOPT Kiosk Player APK on 2 pilot autos for initial road trial."),
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
        set_cell_margins(c0, top=60, bottom=60, left=100, right=100)
        set_cell_margins(c1, top=60, bottom=60, left=100, right=100)

        p0 = c0.paragraphs[0]
        p0.paragraph_format.space_after = Pt(0)
        r0 = p0.add_run(t_time)
        r0.font.bold = True
        r0.font.size = Pt(9.5)
        r0.font.color.rgb = NAVY

        p1 = c1.paragraphs[0]
        p1.paragraph_format.space_after = Pt(0)
        r1 = p1.add_run(t_action)
        r1.font.size = Pt(9.5)

    set_table_borders(pilot_table, color="D2D6DC", sz="4")

    # --- SECTION 6 ---
    add_sec_heading("Conclusion & Next Steps", 6)

    p_concl = doc.add_paragraph()
    p_concl.add_run("This partnership gives ")
    r_ad = p_concl.add_run("Admobitics a rock-solid, production-grade technology platform built specifically for moving auto-rickshaws at zero upfront cost")
    r_ad.font.bold = True
    p_concl.add_run(", allowing Admobitics to focus 100% on securing commercial advertisers and expanding fleet operations, while both companies build prominent brand visibility across Hyderabad.")

    # Sign-off Box
    sign_table = doc.add_table(rows=1, cols=2)
    sign_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    sign_table.autofit = False

    s_c0 = sign_table.rows[0].cells[0]
    s_c1 = sign_table.rows[0].cells[1]
    s_c0.width = Inches(3.35)
    s_c1.width = Inches(3.35)
    set_cell_background(s_c0, "F8FAFC")
    set_cell_background(s_c1, "F8FAFC")
    set_cell_margins(s_c0, top=100, bottom=100, left=100, right=100)
    set_cell_margins(s_c1, top=100, bottom=100, left=100, right=100)

    p_s0 = s_c0.paragraphs[0]
    p_s0.paragraph_format.space_after = Pt(2)
    r = p_s0.add_run("Proposed By:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r.font.color.rgb = SLATE
    r_h = p_s0.add_run("HINOPT Technologies\n")
    r_h.font.bold = True
    r_h.font.size = Pt(11)
    r_h.font.color.rgb = NAVY
    p_s0.add_run("Platform Engineering & Infrastructure\nHyderabad, Telangana\nEmail: contact@hinopt.com")

    p_s1 = s_c1.paragraphs[0]
    p_s1.paragraph_format.space_after = Pt(2)
    r = p_s1.add_run("Accepted & Agreed By:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r.font.color.rgb = SLATE
    r_a = p_s1.add_run("Admobitics Leadership Team\n")
    r_a.font.bold = True
    r_a.font.size = Pt(11)
    r_a.font.color.rgb = NAVY
    p_s1.add_run("In-Auto Digital Advertising Network\nHyderabad, Telangana\nWebsite: admobitics.vercel.app")

    set_table_borders(sign_table, color="CBD5E1", sz="4")

    # Save documents
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

    # Also create a .doc file copy
    doc_path = os.path.splitext(output_path)[0] + ".doc"
    shutil.copyfile(output_path, doc_path)
    print(f"Compatible .doc copy successfully created at: {doc_path}")

if __name__ == "__main__":
    out_docx = r"d:\Advertising & Digital Signage Management Platform\docs\product\admobitics-partnership-pitch-proposal.docx"
    build_pitch_proposal_doc(out_docx)
