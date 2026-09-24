const fs = require('fs');
const path = require('path');
const { jsPDF } = require('jspdf');

const doc = new jsPDF({
  orientation: 'portrait',
  unit: 'mm',
  format: 'a4'
});

const logoPath = path.join('c:', 'Users', 'USER', 'Desktop', 'Rentily', 'mobile', 'assets', 'images', 'logo.png');
let logoData = null;
if (fs.existsSync(logoPath)) {
  const bitmap = fs.readFileSync(logoPath);
  logoData = 'data:image/png;base64,' + bitmap.toString('base64');
}

// ----------------------------------------------------
// PAGE 1: CAMPAIGN OVERVIEW, LOCATIONS, INCENTIVE
// ----------------------------------------------------

// Top Accent Banner
doc.setFillColor(6, 78, 59); // Deep Emerald Green
doc.rect(0, 0, 210, 28, 'F');

doc.setFillColor(16, 185, 129); // Accent Green Line
doc.rect(0, 28, 210, 2, 'F');

if (logoData) {
  doc.addImage(logoData, 'PNG', 14, 4, 20, 20);
}

doc.setFont('helvetica', 'bold');
doc.setFontSize(16);
doc.setTextColor(255, 255, 255);
doc.text('RENTILLY ON THE STREET — IBADAN PILOT', 38, 14);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8.5);
doc.setTextColor(209, 250, 229);
doc.text('Production & Field Execution Manual | Strictly for Crew & Presenter', 38, 20);

// Meta Bar
doc.setFillColor(241, 245, 249);
doc.rect(14, 34, 182, 10, 'F');
doc.setFont('helvetica', 'bold');
doc.setFontSize(8);
doc.setTextColor(15, 23, 42);
doc.text('LOCATION: Ibadan, Oyo State', 18, 40.5);
doc.text('REWARD: N5,000 Cash / Alert (Selective)', 78, 40.5);
doc.text('APP: Google Play Store (Rentilly)', 146, 40.5);

// Section 1: Objective & Concept
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('1. CORE OBJECTIVE & CONTENT PSYCHOLOGY', 14, 52);

doc.setDrawColor(16, 185, 129);
doc.setLineWidth(0.6);
doc.line(14, 54, 196, 54);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8.8);
doc.setTextColor(51, 65, 85);

const objText = 'The goal is to capture high-energy, relatable, and authentic street reactions about rental and agent hardships in Ibadan, introduce Rentilly as the direct-to-landlord solution, and film on-the-spot app downloads rewarded with N5,000. These clips will be distributed across TikTok, Instagram Reels, and YouTube Shorts.';
doc.text(doc.splitTextToSize(objText, 182), 14, 60);

// Callout Box: The 60-Second Video Arc
doc.setFillColor(248, 250, 252);
doc.rect(14, 71, 182, 28, 'F');
doc.setDrawColor(245, 158, 11);
doc.setLineWidth(1.0);
doc.line(14, 71, 14, 99);

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.5);
doc.setTextColor(180, 83, 9);
doc.text('VIRAL VIDEO 4-STEP FORMULA (60 SECONDS MAX):', 18, 77);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8);
doc.setTextColor(30, 41, 59);
doc.text('1. THE HOOK (0-5s): What is the craziest thing an agent has done to you in Ibadan?', 18, 83);
doc.text('2. THE HORROR STORY (5-30s): Let them tell their wild agent experience (fake rooms, stolen fees).', 18, 88);
doc.text('3. THE RENTILLY REVEAL (30-45s): Host introduces Rentilly (Zero agents, direct landlords).', 18, 93);
doc.text('4. DOWNLOAD & N5K REWARD (45-60s): Download on camera + live N5,000 alert/cash + joyful reaction.', 18, 98);

// Section 2: Hotspot Locations in Ibadan
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('2. APPROVED IBADAN SHOOTING LOCATIONS', 14, 107);
doc.line(14, 109, 196, 109);

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.5);
doc.setTextColor(15, 23, 42);

doc.text('- UI Main Gate & Agbowo Junction:', 14, 116);
doc.setFont('helvetica', 'normal');
doc.text('Students & NYSC corps members with insane hostel agent horror stories.', 70, 116);

doc.setFont('helvetica', 'bold');
doc.text('- Ventura Mall (Samonda):', 14, 123);
doc.setFont('helvetica', 'normal');
doc.text('Young professionals, couples, and techies relaxed with time to talk.', 70, 123);

doc.setFont('helvetica', 'bold');
doc.text('- Palms Mall / Ring Road:', 14, 130);
doc.setFont('helvetica', 'normal');
doc.text('Corporate workers, families, and tenants dealing with high Lagos/Ibadan rents.', 70, 130);

doc.setFont('helvetica', 'bold');
doc.text('- Bodija Housing Estate / Market:', 14, 137);
doc.setFont('helvetica', 'normal');
doc.text('Family flat seekers and direct landlord dispute experiences.', 70, 137);

// Section 3: Reward Strategy & Zero-KYC Rule
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('3. SELECTIVE REWARD & FRICTIONLESS ZERO-KYC RULE', 14, 147);
doc.line(14, 149, 196, 149);

doc.setFillColor(254, 242, 242);
doc.rect(14, 154, 38, 38, 'F');
doc.setFillColor(254, 242, 242);
doc.rect(14, 154, 182, 38, 'F');
doc.setDrawColor(239, 68, 68);
doc.setLineWidth(1.0);
doc.line(14, 154, 14, 192);

doc.setFont('helvetica', 'bold');
doc.setFontSize(9);
doc.setTextColor(185, 28, 28);
doc.text('CRITICAL CREW INSTRUCTION: NO KYC / NO BVN / NO NIN ON THE STREET!', 18, 161);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8.2);
doc.setTextColor(51, 65, 85);
doc.text('* DO NOT ask users to upload IDs, NIN, or utility bills on camera. That completely kills momentum.', 18, 168);
doc.text('* DOWNLOAD & PHONE OTP ONLY: Open Play Store -> Install Rentilly -> Enter Phone -> Enter OTP (30 secs).', 18, 174);
doc.text('* SELECTIVE REWARDS ONLY: Interview 30 people, but reward ONLY the 6-8 wildest/funniest stories.', 18, 180);
doc.text('* IF A STORY IS DULL: Thank them politely, hand a small Rentilly sweet/sticker, and move to the next person.', 18, 186);

// Section 4: Hotspot WiFi Hack
doc.setFillColor(236, 253, 245);
doc.rect(14, 198, 182, 22, 'F');
doc.setDrawColor(16, 185, 129);
doc.setLineWidth(1.0);
doc.line(14, 198, 14, 220);

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.5);
doc.setTextColor(6, 78, 59);
doc.text('FIELD HACK: THE "NO DATA" SOLUTION', 18, 205);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8);
doc.setTextColor(51, 65, 85);
doc.text('Never let a participant say "I do not have data to download". The Production Assistant must carry a portable', 18, 211);
doc.text('MTN/Airtel MiFi with a visible hotspot named "Rentilly-Free-WiFi" to connect them in 5 seconds.', 18, 216);

// Section 5: Roles & Responsibilities
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('4. PRODUCTION CREW ROLES (3-PERSON TEAM)', 14, 230);
doc.line(14, 232, 196, 232);

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.5);
doc.setTextColor(15, 23, 42);
doc.text('1. The Host / Presenter:', 14, 239);
doc.setFont('helvetica', 'normal');
doc.text('Wears green Rentilly shirt & mic cube. Charismatic, street-smart, speaks fluent Pidgin & Yoruba.', 52, 239);

doc.setFont('helvetica', 'bold');
doc.text('2. Videographer:', 14, 246);
doc.setFont('helvetica', 'normal');
doc.text('Shoots vertical 9:16 on iPhone (4K 60fps) on a DJI gimbal + wireless lavalier mic (DJI Mic / Rode).', 52, 246);

doc.setFont('helvetica', 'bold');
doc.text('3. Production Assistant:', 14, 253);
doc.setFont('helvetica', 'normal');
doc.text('Carries MiFi, power bank, holds crisp cash / triggers instant bank alert, monitors crowd security.', 52, 253);

// Page 1 Footer
doc.setDrawColor(226, 232, 240);
doc.line(14, 280, 196, 280);
doc.setFont('helvetica', 'normal');
doc.setFontSize(7.5);
doc.setTextColor(148, 163, 184);
doc.text('Rentilly Mobile Platform - Field Operations Manual | Page 1 of 2', 14, 285);
doc.text('Confidential - Internal Production Use Only', 196, 285, { align: 'right' });


// ----------------------------------------------------
// PAGE 2: SCRIPTING, FLOW, BUDGET & CHECKLIST
// ----------------------------------------------------
doc.addPage();

// Top Banner Page 2
doc.setFillColor(6, 78, 59);
doc.rect(0, 0, 210, 20, 'F');
doc.setFillColor(16, 185, 129);
doc.rect(0, 20, 210, 1.5, 'F');

doc.setFont('helvetica', 'bold');
doc.setFontSize(12);
doc.setTextColor(255, 255, 255);
doc.text('PRESENTER WORD-FOR-WORD SCRIPT & FIELD CHECKLIST', 14, 13);

// Section 5: Exact Script
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('5. WORD-FOR-WORD HOST INTERVIEW SCRIPT', 14, 30);
doc.setDrawColor(16, 185, 129);
doc.setLineWidth(0.6);
doc.line(14, 32, 196, 32);

// Script Dialogue Box
doc.setFillColor(248, 250, 252);
doc.rect(14, 36, 182, 118, 'F');

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.2);
doc.setTextColor(6, 78, 59);
doc.text('HOST (Warm greeting):', 18, 43);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"E kaasan o! How far na? Quick question: You don rent house or room for this Ibadan before?\"', 18, 48);

doc.setFont('helvetica', 'bold');
doc.setTextColor(242, 100, 25);
doc.text('PASSING PERSON:', 18, 55);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Ah! My brother, more than five times o! Ibadan agents na die!\"', 18, 60);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('HOST (Digging for the horror story):', 18, 67);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Tell me the single craziest, most wicked thing an agent has done to you in this town!\"', 18, 72);

doc.setFont('helvetica', 'bold');
doc.setTextColor(242, 100, 25);
doc.text('PASSING PERSON (Tells the wild story):', 18, 79);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Bro! In Agbowo, one agent collected N15,000 inspection fee to show me a room. When we reach there,', 18, 84);
doc.text('another boy was sleeping inside! Agent told me to wait till next week. He vanished with my money!\"', 18, 89);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('HOST (Shocked reaction to camera):', 18, 96);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Ehn?! N15k inspection for an occupied room?! [To camera] Ibadan agents will not kill us in this town!\"', 18, 101);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('HOST (The Solution & Reward Trigger):', 18, 108);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Look, this story shocked me! What if I told you that with Rentilly, you deal DIRECTLY with landlords,', 18, 113);
doc.text('zero agent fee, zero inspection fee? Bring your phone right now. Search \'Rentilly\' on Google Play Store!\"', 18, 118);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('HOST (Live Download & Cashout):', 18, 125);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Download it... Put your phone number... Logged in! Because your story is the wildest today,', 18, 130);
doc.text('here is N5,000 cash [or transfer alert] from Rentilly to ease your pain! What is Rentilly?\"', 18, 135);

doc.setFont('helvetica', 'bold');
doc.setTextColor(242, 100, 25);
doc.text('PERSON (Joyful screaming / Bank alert):', 18, 142);
doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"AHHH! ALERT ENTERED! N5,000 SHARP! Rentilly is real o! No more agent wahala!\"', 18, 147);

// Section 6: Budget Table
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('6. PRODUCTION BUDGET ESTIMATE (IBADAN PILOT)', 14, 162);
doc.line(14, 164, 196, 164);

// Table Header
doc.setFillColor(6, 78, 59);
doc.rect(14, 168, 182, 7, 'F');
doc.setFont('helvetica', 'bold');
doc.setFontSize(8);
doc.setTextColor(255, 255, 255);
doc.text('ITEM DESCRIPTION', 18, 173);
doc.text('QTY / RATE', 120, 173);
doc.text('ESTIMATED COST', 165, 173);

// Rows
const rows = [
  ['Selective Cash Rewards (Top 8 Wildest Stories)', '8 winners x N5,000', 'N 40,000'],
  ['Videographer Day Rate (iPhone 14/15 Pro, DJI Gimbal & Audio)', '1 Day Shoot', 'N 30,000'],
  ['Host / Street Presenter Day Rate (Local Ibadan Creator)', '1 Day Shoot', 'N 25,000'],
  ['Branded Rentilly Gear (2x Green T-Shirts & Custom Mic Foam)', '1 Production Pack', 'N 15,000'],
  ['Field Logistics, Refreshments & Mobile Data MiFi', 'Lump Sum', 'N 15,000'],
];

let yPos = 175;
rows.forEach((r, idx) => {
  yPos += 6.5;
  doc.setFillColor(idx % 2 === 0 ? 248 : 255, idx % 2 === 0 ? 250 : 255, idx % 2 === 0 ? 252 : 255);
  doc.rect(14, yPos - 4.5, 182, 6.5, 'F');
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.8);
  doc.setTextColor(51, 65, 85);
  doc.text(r[0], 18, yPos);
  doc.text(r[1], 120, yPos);
  doc.setFont('helvetica', 'bold');
  doc.text(r[2], 165, yPos);
});

// Total Row
yPos += 7;
doc.setFillColor(236, 253, 245);
doc.rect(14, yPos - 5, 182, 7, 'F');
doc.setFont('helvetica', 'bold');
doc.setFontSize(8.5);
doc.setTextColor(6, 78, 59);
doc.text('TOTAL ESTIMATED PILOT BUDGET', 18, yPos);
doc.text('N 125,000', 165, yPos);

// Section 7: Pre-Shoot Checklist
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('7. PRE-SHOOT GEAR & FIELD CHECKLIST', 14, 230);
doc.line(14, 232, 196, 232);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8);
doc.setTextColor(51, 65, 85);

doc.text('[  ] Wireless Mic transmitters paired and tested (DJI Mic or Rode Wireless Go).', 18, 239);
doc.text('[  ] Green Rentilly T-Shirts ironed; Mic foam securely fitted with Rentilly branding.', 18, 245);
doc.text('[  ] iPhone storage cleared (at least 50GB free for 4K 60fps vertical video).', 18, 251);
doc.text('[  ] 20,000mAh Power Bank + lightning/USB-C cables packed.', 18, 257);
doc.text('[  ] MTN / Airtel 4G MiFi loaded with data and active hotspot: \"Rentilly-Free-WiFi\".', 18, 263);
doc.text('[  ] N40,000 cash / mobile banking app funded for instant live rewards on camera.', 18, 269);

// Page 2 Footer
doc.setDrawColor(226, 232, 240);
doc.line(14, 280, 196, 280);
doc.setFont('helvetica', 'normal');
doc.setFontSize(7.5);
doc.setTextColor(148, 163, 184);
doc.text('Rentilly Mobile Platform - Field Operations Manual | Page 2 of 2', 14, 285);
doc.text('Confidential - Internal Production Use Only', 196, 285, { align: 'right' });

// Output Path
const destPath = path.join('C:', 'Users', 'USER', 'Downloads', 'Rentilly_On_The_Street_Production_Guide.pdf');
const pdfBuffer = Buffer.from(doc.output('arraybuffer'));
fs.writeFileSync(destPath, pdfBuffer);
console.log('SUCCESS: PDF generated at: ' + destPath);
