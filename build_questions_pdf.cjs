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
// PAGE 1: DYNAMIC STREET QUESTIONS & CATEGORIES
// ----------------------------------------------------

// Top Accent Banner
doc.setFillColor(6, 78, 59); // Deep Emerald Green
doc.rect(0, 0, 210, 26, 'F');

doc.setFillColor(16, 185, 129); // Accent Green Line
doc.rect(0, 26, 210, 1.8, 'F');

if (logoData) {
  doc.addImage(logoData, 'PNG', 14, 3, 20, 20);
}

doc.setFont('helvetica', 'bold');
doc.setFontSize(15);
doc.setTextColor(255, 255, 255);
doc.text('RENTILLY ON THE STREET — PRESENTER QUESTION GUIDE', 38, 13);

doc.setFont('helvetica', 'normal');
doc.setFontSize(8.5);
doc.setTextColor(209, 250, 229);
doc.text('High-Energy Street Interview Prompts | Instant Download & Cash Reward Flow', 38, 19);

// Concept Banner
doc.setFillColor(241, 245, 249);
doc.rect(14, 32, 182, 13, 'F');
doc.setFont('helvetica', 'bold');
doc.setFontSize(8.2);
doc.setTextColor(6, 78, 59);
doc.text('CORE FLOW: Ask Question -> Capture Wild Reaction -> User Downloads Rentilly -> Hand Over N5,000 Cash', 18, 38);
doc.setFont('helvetica', 'normal');
doc.setFontSize(7.8);
doc.setTextColor(51, 65, 85);
doc.text('Keep energy high! When someone drops a crazy, shocking, or hilarious story, reward them on camera immediately!', 18, 42.5);

// Category 1: The "Agent Wahala & Scam" Hooks
doc.setFont('helvetica', 'bold');
doc.setFontSize(10.5);
doc.setTextColor(6, 78, 59);
doc.text('CATEGORY 1: "AGENT WAHALA & SCAM STORIES" (HIGHEST VIRAL ENGAGEMENT)', 14, 52);
doc.setDrawColor(16, 185, 129);
doc.setLineWidth(0.6);
doc.line(14, 54, 196, 54);

const cat1 = [
  'Q1: "What is the single most wicked thing a house agent has ever done to you in this Ibadan?"',
  'Q2: "Have you ever paid an \'inspection fee\' for an apartment that was completely different from photos?"',
  'Q3: "Tell me the truth: What is the highest total amount of inspection fee you have wasted without getting a house?"',
  'Q4: "Has an agent ever taken you into an uncompleted building or a bush and told you \'development is coming\'?"',
  'Q5: "Has an agent ever collected your money and told you the landlord traveled out of the country?"'
];

let y = 60;
cat1.forEach(q => {
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.2);
  doc.setTextColor(15, 23, 42);
  doc.text(q.substring(0, 4), 14, y);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(51, 65, 85);
  doc.text(doc.splitTextToSize(q.substring(4), 174), 22, y);
  y += 7;
});

// Category 2: Price Shock & "Total Package" Outrage
y += 3;
doc.setFont('helvetica', 'bold');
doc.setFontSize(10.5);
doc.setTextColor(6, 78, 59);
doc.text('CATEGORY 2: RENT PRICE SHOCK & "TOTAL PACKAGE" OUTRAGE', 14, y);
doc.line(14, y + 2, 196, y + 2);
y += 8;

const cat2 = [
  'Q6: "You see a house of N400k, then agent tells you Total Package is N850k. How did you react?"',
  'Q7: "Between Agreement fee, Caution fee, and Agent fee, which one pain you pass to pay?"',
  'Q8: "What is the most ridiculous rule a landlord or caretaker has ever given you before giving you keys?"',
  'Q9: "If you calculate all the agent fees you have paid in your life, what big thing could that money buy you now?"'
];

cat2.forEach(q => {
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.2);
  doc.setTextColor(15, 23, 42);
  doc.text(q.substring(0, 4), 14, y);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(51, 65, 85);
  doc.text(doc.splitTextToSize(q.substring(4), 174), 22, y);
  y += 7;
});

// Category 3: Students & Off-Campus Drama (UI, Poly, Agbowo, Samonda)
y += 3;
doc.setFont('helvetica', 'bold');
doc.setFontSize(10.5);
doc.setTextColor(6, 78, 59);
doc.text('CATEGORY 3: STUDENT & YOUTH HOSTEL DRAMA (PERFECT FOR UI / SAMONDA)', 14, y);
doc.line(14, y + 2, 196, y + 2);
y += 8;

const cat3 = [
  'Q10: "As a student or youth in Ibadan, what is your worst experience hunting for a self-contain around campus?"',
  'Q11: "Have you ever rented a room where tap no dey rush, light is 1 hour a week, but rent is 100% full?"',
  'Q12: "Has an agent ever collected hostel form fee from 10 different students for the same one room?"',
  'Q13: "What is the funniest lie an agent told you just to make you pay caution fee on the spot?"'
];

cat3.forEach(q => {
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.2);
  doc.setTextColor(15, 23, 42);
  doc.text(q.substring(0, 4), 14, y);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(51, 65, 85);
  doc.text(doc.splitTextToSize(q.substring(4), 174), 22, y);
  y += 7;
});

// Category 4: The Provocative "Would You Rather" & Quick-Fire
y += 3;
doc.setFont('helvetica', 'bold');
doc.setFontSize(10.5);
doc.setTextColor(6, 78, 59);
doc.text('CATEGORY 4: QUICK-FIRE & PROVOCATIVE QUESTIONS (HIGH RETENTION CLIPS)', 14, y);
doc.line(14, y + 2, 196, y + 2);
y += 8;

const cat4 = [
  'Q14: "Would you rather sleep inside a car for 3 days or deal with a notorious Ibadan agent for 1 week?"',
  'Q15: "Rate your current landlord from 1 to 10. Why did you give that score?"',
  'Q16: "If you become Governor of Oyo State today, what law will you make against house agents?"',
  'Q17: "Have you ever seen a house with kitchen inside bathroom before? Tell me the truth!"'
];

cat4.forEach(q => {
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.2);
  doc.setTextColor(15, 23, 42);
  doc.text(q.substring(0, 4), 14, y);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(51, 65, 85);
  doc.text(doc.splitTextToSize(q.substring(4), 174), 22, y);
  y += 7;
});

// Page 1 Footer
doc.setDrawColor(226, 232, 240);
doc.line(14, 280, 196, 280);
doc.setFont('helvetica', 'normal');
doc.setFontSize(7.5);
doc.setTextColor(148, 163, 184);
doc.text('Rentilly Mobile Platform - Street Interview Manual | Page 1 of 2', 14, 285);
doc.text('Empowering Renters with Zero-Agent Freedom', 196, 285, { align: 'right' });


// ----------------------------------------------------
// PAGE 2: THE CASH-HANDOVER & DOWNLOAD SCRIPT
// ----------------------------------------------------
doc.addPage();

// Top Banner Page 2
doc.setFillColor(6, 78, 59);
doc.rect(0, 0, 210, 22, 'F');
doc.setFillColor(16, 185, 129);
doc.rect(0, 22, 210, 1.8, 'F');

doc.setFont('helvetica', 'bold');
doc.setFontSize(13);
doc.setTextColor(255, 255, 255);
doc.text('THE CONVERSION: ON-CAMERA APP DOWNLOAD & CASH HANDOVER', 14, 14);

// Section: The Transition Moment
doc.setFont('helvetica', 'bold');
doc.setFontSize(11);
doc.setTextColor(6, 78, 59);
doc.text('HOW TO TRANSITION FROM THE STORY TO THE DOWNLOAD & CASH', 14, 33);
doc.setDrawColor(16, 185, 129);
doc.setLineWidth(0.6);
doc.line(14, 35, 196, 35);

// Transition Script Box
doc.setFillColor(248, 250, 252);
doc.rect(14, 40, 182, 138, 'F');
doc.setDrawColor(245, 158, 11);
doc.setLineWidth(1.2);
doc.line(14, 40, 14, 178);

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.5);
doc.setTextColor(6, 78, 59);
doc.text('STEP 1: HOST VALIDATES THE STORY & CREATES THE PEAK MOMENT', 18, 47);

doc.setFont('helvetica', 'italic');
doc.setFontSize(8.2);
doc.setTextColor(51, 65, 85);
doc.text('\"No way! That is the single craziest agent story in Ibadan today! Look at my face, I am in shock!\"', 18, 53);
doc.text('\"Why are we still suffering from agent wahala, form fee, and inspection fee in 2026?!\"', 18, 58);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('STEP 2: THE RENTILLY SOLUTION PITCH', 18, 68);

doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"What if I told you that you never have to pay agent fee or form fee in Nigeria again?\"', 18, 74);
doc.text('\"With RENTILLY, you connect DIRECTLY with verified landlords and property owners! ZERO percent agent fee!\"', 18, 79);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('STEP 3: THE LIVE DOWNLOAD ON CAMERA (OVER-THE-SHOULDER SHOT)', 18, 89);

doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Bring out your phone right now. Open Google Play Store. Type \'Rentilly\'.\"', 18, 95);
doc.text('\"[Camera zooms onto the phone screen downloading Rentilly]\"', 18, 100);
doc.text('\"Tap Install... Open it... Enter your phone number... boom, 4-digit OTP entered! You are inside!\"', 18, 105);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('STEP 4: THE N5,000 CASH HANDOVER (THE MONEY SHOT)', 18, 115);

doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Because your story shocked everyone and you just joined the zero-agent movement with Rentilly...\"', 18, 121);
doc.text('\"...Take this fresh N5,000 CASH [or instant credit bank alert] right now!\"', 18, 126);
doc.text('\"[Host counts out or hands over crisp N5,000 cash directly on camera]\"', 18, 131);

doc.setFont('helvetica', 'bold');
doc.setTextColor(242, 100, 25);
doc.text('STEP 5: THE CELEBRATION & PARTICIPANT SHOUTOUT', 18, 141);

doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"PARTICIPANT: [Jumping, smiling, holding cash to camera] Ahhh! N5,000 cash! Rentilly is real!\"', 18, 147);
doc.text('\"HOST: What is the app called?\"', 18, 152);
doc.text('\"PARTICIPANT: RENTILLY! No more agent wahala!\"', 18, 157);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('STEP 6: CALL TO ACTION OUTRO (HOST DIRECT TO CAMERA)', 18, 167);

doc.setFont('helvetica', 'italic');
doc.setTextColor(51, 65, 85);
doc.text('\"Stop letting agents chop your hard-earned money! Download RENTILLY on Google Play Store today!\"', 18, 173);

// Section: Golden Rules for the Presenter & Camera
doc.setFont('helvetica', 'bold');
doc.setFontSize(10.5);
doc.setTextColor(6, 78, 59);
doc.text('FIELD RULES FOR MAXIMUM VIRAL ENGAGEMENT', 14, 188);
doc.line(14, 190, 196, 190);

doc.setFillColor(236, 253, 245);
doc.rect(14, 195, 182, 40, 'F');
doc.setDrawColor(16, 185, 129);
doc.setLineWidth(1.0);
doc.line(14, 195, 14, 235);

doc.setFont('helvetica', 'bold');
doc.setFontSize(8.2);
doc.setTextColor(6, 78, 59);
doc.text('1. LET THEM VENT:', 18, 202);
doc.setFont('helvetica', 'normal');
doc.setTextColor(51, 65, 85);
doc.text('Do not interrupt their story. The angrier, funnier, or more emotional they get about the agent, the more viral the clip.', 50, 202);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('2. ZOOM ON CASH:', 18, 210);
doc.setFont('helvetica', 'normal');
doc.setTextColor(51, 65, 85);
doc.text('When handing over the N5,000 cash, the camera must get a clean close-up shot of the money in their hand.', 50, 210);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('3. ZERO DELAY:', 18, 218);
doc.setFont('helvetica', 'normal');
doc.setTextColor(51, 65, 85);
doc.text('Download -> Phone OTP -> Logged In -> Hand Cash! Never ask for BVN, NIN or ID on the street.', 50, 218);

doc.setFont('helvetica', 'bold');
doc.setTextColor(6, 78, 59);
doc.text('4. HOTSPOT READY:', 18, 226);
doc.setFont('helvetica', 'normal');
doc.setTextColor(51, 65, 85);
doc.text('If they claim \"no data\", connect them immediately to your MiFi (\"Rentilly-Free-WiFi\").', 50, 226);

// Checklist Bar
doc.setFillColor(241, 245, 249);
doc.rect(14, 242, 182, 16, 'F');
doc.setFont('helvetica', 'bold');
doc.setFontSize(8);
doc.setTextColor(15, 23, 42);
doc.text('QUICK GEAR AUDIT: [  ] Wireless Mic  |  [  ] Green Rentilly Shirt  |  [  ] Crisp N5,000 Cash Notes  |  [  ] MiFi Hotspot', 18, 251);

// Page 2 Footer
doc.setDrawColor(226, 232, 240);
doc.line(14, 275, 196, 275);
doc.setFont('helvetica', 'normal');
doc.setFontSize(7.5);
doc.setTextColor(148, 163, 184);
doc.text('Rentilly Mobile Platform - Street Interview Manual | Page 2 of 2', 14, 281);
doc.text('Live on Google Play: ng.rentilly.rentilly_mobile', 196, 281, { align: 'right' });

// Output Path
const destPath = path.join('C:', 'Users', 'USER', 'Downloads', 'Rentilly_Street_Interview_Questions_Guide.pdf');
const pdfBuffer = Buffer.from(doc.output('arraybuffer'));
fs.writeFileSync(destPath, pdfBuffer);
console.log('SUCCESS: Generated at ' + destPath);
