import { jsPDF } from 'jspdf';
import fs from 'fs';
import path from 'path';

function generateProfessionalPdf() {
  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4'
  });

  // Page Dimensions: 210 x 297 mm
  const margin = 14;
  const contentWidth = 210 - (margin * 2); // 182 mm

  // ==========================================
  // PAGE 1: COMMERCIAL QUOTE & PRO-FORMA INVOICE
  // ==========================================

  // 1. Header Banner
  doc.setFillColor(15, 23, 42); // Slate 900
  doc.rect(0, 0, 210, 38, 'F');

  // Accent Line
  doc.setFillColor(14, 165, 233); // Sky 500
  doc.rect(0, 38, 210, 2, 'F');

  // Brand Name & Tagline
  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(20);
  doc.text('DRIVE LOGISTICS UK', margin, 16);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8.5);
  doc.setTextColor(148, 163, 184); // Slate 400
  doc.text('Global Freight Forwarding  |  Customs Brokerage  |  Cross-Border Supply Chain', margin, 23);
  doc.text('Company Reg: 12894560  |  EORI: GB123456789000  |  VAT: GB 987 6543 21', margin, 29);

  // Quote Ref Badge (Top Right)
  doc.setFillColor(30, 41, 59); // Slate 800
  doc.setDrawColor(51, 65, 85);
  doc.roundedRect(132, 6, 64, 26, 2, 2, 'FD');

  doc.setTextColor(56, 189, 248); // Sky 400
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('OFFICIAL FREIGHT QUOTE', 136, 12);

  doc.setTextColor(255, 255, 255);
  doc.setFontSize(13);
  doc.text('REF: PDF 148144', 136, 20);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(203, 213, 225);
  doc.text('Date: 01 Sept 2026  |  Valid: 30 Days', 136, 27);

  // 2. Address Cards (Shipper / Consignee)
  const addrY = 45;
  const cardWidth = (contentWidth - 6) / 2; // 88 mm
  const cardHeight = 44;

  // Shipper Card (Left)
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.roundedRect(margin, addrY, cardWidth, cardHeight, 2, 2, 'FD');

  doc.setTextColor(14, 165, 233);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('ORIGIN / PICKUP ADDRESS (UK)', margin + 4, addrY + 6);

  doc.setTextColor(15, 23, 42);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('Prepared on behalf of: Drive Logistics UK', margin + 4, addrY + 13);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(71, 85, 105);
  doc.text('Collection Point: 142 High Holborn', margin + 4, addrY + 19);
  doc.text('City / Postal: London, WC1V 6PX, United Kingdom', margin + 4, addrY + 25);
  doc.text('Contact: Export Operations (+44 20 7946 0912)', margin + 4, addrY + 31);
  doc.text('Email: operations@drivelogistics.co.uk', margin + 4, addrY + 37);

  // Consignee Card (Right)
  const rightCardX = margin + cardWidth + 6;
  doc.setFillColor(248, 250, 252);
  doc.roundedRect(rightCardX, addrY, cardWidth, cardHeight, 2, 2, 'FD');

  doc.setTextColor(16, 185, 129); // Emerald 600
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('DESTINATION / FINAL DELIVERY (UAE)', rightCardX + 4, addrY + 6);

  doc.setTextColor(15, 23, 42);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('Consignee: Al Jurf Receiving Desk', rightCardX + 4, addrY + 13);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(71, 85, 105);
  doc.text('Address: Al Jurf 1, Ajman, United Arab Emirates', rightCardX + 4, addrY + 19);
  
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(15, 23, 42);
  doc.text('Landmark: Behind Marks & Spencer', rightCardX + 4, addrY + 25);
  doc.text('Adjacent: Next to Al Kahf Cafeteria', rightCardX + 4, addrY + 30);
  
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(71, 85, 105);
  doc.text('Contact: Inbound Logistics Desk (+971 6 740 0000)', rightCardX + 4, addrY + 37);

  // 3. Cargo Summary Banner
  const cargoY = 93;
  doc.setFillColor(15, 23, 42);
  doc.roundedRect(margin, cargoY, contentWidth, 14, 2, 2, 'F');

  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('CONSIGNMENT SPECIFICATION: 250.0 KG TOYS & GAMES (10 MASTER CARTONS)', margin + 5, cargoY + 5.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(148, 163, 184);
  doc.text('HS Codes: 9503.00.35 / 70 / 41  |  Declared Value: GBP 4,500.00 (AED 21,375.00)  |  Vol: 0.96 CBM  |  Terms: DAP', margin + 5, cargoY + 10.5);

  // 4. Quotation Breakdown Table
  let tableY = 112;
  doc.setTextColor(15, 23, 42);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10.5);
  doc.text('ALL-INCLUSIVE DOOR-TO-DOOR QUOTATION COMPARISON', margin, tableY);

  tableY += 4;

  // Table Column Definitions
  // Total content width = 182mm
  // Col 1 (Service Description): width = 110 mm (X: 14 to 124)
  // Col 2 (Air Freight): width = 36 mm (X: 124 to 160)
  // Col 3 (Sea Freight): width = 36 mm (X: 160 to 196)
  const col1X = margin;
  const col2X = margin + 110;
  const col3X = margin + 146;
  const endX = margin + contentWidth;

  // Header Row
  doc.setFillColor(241, 245, 249);
  doc.setDrawColor(203, 213, 225);
  doc.rect(margin, tableY, contentWidth, 7, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(51, 65, 85);
  doc.text('LOGISTICS SERVICE & INCLUDED COMPONENTS', col1X + 4, tableY + 4.8);
  doc.text('AIR FREIGHT (EXPRESS)', col2X + 18, tableY + 4.8, { align: 'center' });
  doc.text('SEA FREIGHT (LCL OCEAN)', col3X + 18, tableY + 4.8, { align: 'center' });

  tableY += 7;

  const quoteRows = [
    {
      title: '1. UK Domestic Door Pickup',
      subtitle: 'Tail-lift collection from London shipper address to central export depot',
      air: 'GBP 250.00',
      sea: 'GBP 220.00'
    },
    {
      title: '2. UK Export Handling & Security Screening',
      subtitle: 'Depot consolidation, cargo labeling, security X-ray & export manifest filing',
      air: 'GBP 180.00',
      sea: 'GBP 160.00'
    },
    {
      title: '3. UK Customs Export Declaration',
      subtitle: 'HMRC CDS formal electronic export declaration & commodity clearance',
      air: 'GBP 75.00',
      sea: 'GBP 75.00'
    },
    {
      title: '4. International Freight Carriage',
      subtitle: 'Direct air transport (LHR -> DXB) or Ocean container freight (Southampton -> Jebel Ali)',
      air: 'GBP 1,520.00',
      sea: 'GBP 1,150.00'
    },
    {
      title: '5. Fuel Surcharge / BAF & Carrier Security',
      subtitle: 'Airline fuel surcharge / ocean Bunker Adjustment Factor (BAF) & ISPS fees',
      air: 'GBP 265.00',
      sea: 'GBP 185.00'
    },
    {
      title: '6. Destination Port / Airport Handling (THC)',
      subtitle: 'UAE inbound terminal handling charges & bonded warehouse transfer',
      air: 'GBP 210.00',
      sea: 'GBP 170.00'
    },
    {
      title: '7. UAE Customs Clearance & Delivery Order (DO)',
      subtitle: 'Ajman/Dubai import customs processing, inspection & DO issuance fee',
      air: 'GBP 110.00',
      sea: 'GBP 110.00'
    },
    {
      title: '8. Final Mile Door Delivery to Ajman',
      subtitle: 'Dedicated truck delivery to Al Jurf 1, Ajman (Behind M&S / Next to Al Kahf)',
      air: 'GBP 190.00',
      sea: 'GBP 180.00'
    }
  ];

  quoteRows.forEach((r, idx) => {
    const rowH = 8.2;
    if (idx % 2 === 0) {
      doc.setFillColor(255, 255, 255);
    } else {
      doc.setFillColor(248, 250, 252);
    }
    doc.rect(margin, tableY, contentWidth, rowH, 'FD');

    // Title
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);
    doc.setTextColor(15, 23, 42);
    doc.text(r.title, col1X + 4, tableY + 3.8);

    // Subtitle
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6.5);
    doc.setTextColor(100, 116, 139);
    doc.text(r.subtitle, col1X + 4, tableY + 7);

    // Pricing Columns (Right aligned)
    doc.setFont('courier', 'bold');
    doc.setFontSize(8);
    doc.setTextColor(30, 41, 59);
    doc.text(r.air, col2X + 32, tableY + 5.2, { align: 'right' });
    doc.text(r.sea, col3X + 32, tableY + 5.2, { align: 'right' });

    tableY += rowH;
  });

  // Transit Time Row
  doc.setFillColor(241, 245, 249);
  doc.rect(margin, tableY, contentWidth, 7, 'FD');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(51, 65, 85);
  doc.text('ESTIMATED TRANSIT TIME (DOOR-TO-DOOR):', col1X + 4, tableY + 4.8);

  doc.setTextColor(14, 165, 233);
  doc.text('3 - 5 Business Days', col2X + 18, tableY + 4.8, { align: 'center' });

  doc.setTextColor(16, 185, 129);
  doc.text('18 - 24 Days (LCL)', col3X + 18, tableY + 4.8, { align: 'center' });

  tableY += 7;

  // Grand Total Highlight Row
  doc.setFillColor(15, 23, 42);
  doc.rect(margin, tableY, contentWidth, 10, 'F');

  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.text('TOTAL ALL-INCLUSIVE DOOR-TO-DOOR PRICE:', col1X + 4, tableY + 6.5);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.setTextColor(56, 189, 248);
  doc.text('£ 2,800.00', col2X + 32, tableY + 6.8, { align: 'right' });

  doc.setTextColor(52, 211, 153);
  doc.text('£ 2,250.00', col3X + 32, tableY + 6.8, { align: 'right' });

  tableY += 14;

  // 5. Scope & Terms Box
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.roundedRect(margin, tableY, contentWidth, 34, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(15, 23, 42);
  doc.text('QUOTATION CONDITIONS & OPERATIONAL NOTES', margin + 4, tableY + 5.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(71, 85, 105);
  const terms = [
    '• Comprehensive Inclusions: Complete door pickup in London, UK export filing, air/sea linehaul, UAE customs clearance, and delivery to Al Jurf 1, Ajman.',
    '• UAE Customs Duties & VAT: Assessed by UAE Customs at 5% duty + 5% VAT on CIF value (approx. AED 2,190 / £461) and settled per assessment receipt.',
    '• Cargo Packaging: Packed in 10 heavy-duty corrugated cartons (25kg each, 60x40x40cm). Commercial toy items free of hazardous materials or uncertified batteries.',
    '• Confirmation: To approve and book either option (Air @ £2,800 or Sea @ £2,250), quote reference PDF 148144 to operations@drivelogistics.co.uk.'
  ];
  terms.forEach((t, i) => {
    doc.text(t, margin + 4, tableY + 11 + (i * 4.8), { maxWidth: contentWidth - 8 });
  });

  // Footer
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(148, 163, 184);
  doc.text('Drive Logistics UK  |  Quotation Ref: PDF 148144  |  Page 1 of 2', margin, 290);
  doc.text('Commercial Freight Quote & Pro-Forma Invoice', endX, 290, { align: 'right' });


  // ==========================================
  // PAGE 2: CUSTOMS EXPORT DECLARATION & MANIFEST
  // ==========================================
  doc.addPage('a4', 'portrait');

  // Header Banner Page 2
  doc.setFillColor(15, 23, 42);
  doc.rect(0, 0, 210, 36, 'F');
  doc.setFillColor(16, 185, 129); // Emerald accent
  doc.rect(0, 36, 210, 2, 'F');

  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.text('CUSTOMS EXPORT DECLARATION & CARGO MANIFEST', margin, 16);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(148, 163, 184);
  doc.text('HM Revenue & Customs (UK) Export Clearance Entry  |  Reference: PDF 148144', margin, 23);
  doc.text('Filing Agent: Drive Logistics UK (Customs Brokerage Division)  |  Consignment: 250 KG TOYS', margin, 29);

  let p2Y = 44;

  // Administrative Identifiers Card
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.roundedRect(margin, p2Y, contentWidth, 30, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8.5);
  doc.setTextColor(15, 23, 42);
  doc.text('EXPORT & IMPORT REGULATORY IDENTIFIERS', margin + 4, p2Y + 6);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(71, 85, 105);

  // Left Column
  doc.text('• Exporter: Drive Logistics UK (on behalf of London Toys)', margin + 4, p2Y + 12);
  doc.text('• UK EORI Number: GB123456789000  |  VAT: GB 987 6543 21', margin + 4, p2Y + 18);
  doc.text('• Country of Dispatch: United Kingdom (GB)', margin + 4, p2Y + 24);

  // Right Column
  const p2RightColX = margin + 96;
  doc.text('• Destination: Al Jurf 1, Ajman, UAE (AE)', p2RightColX, p2Y + 12);
  doc.text('• Landmark: Behind Marks & Spencer / Next to Al Kahf', p2RightColX, p2Y + 18);
  doc.text('• Export Reason: Permanent Commercial Trade  |  Terms: DAP', p2RightColX, p2Y + 24);

  p2Y += 36;

  // Customs Commodity Table
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.setTextColor(15, 23, 42);
  doc.text('ITEMIZED COMMODITY CLASSIFICATION (TOYS & GAMES - 250.0 KG)', margin, p2Y);

  p2Y += 4;

  // Column layout for page 2:
  // Item Desc: 80mm
  // HS Code: 30mm
  // Quantity: 24mm
  // Net Wt: 20mm
  // Declared: 28mm
  // Total: 182mm
  const cDescX = margin;
  const cHsX = margin + 80;
  const cQtyX = margin + 110;
  const cWtX = margin + 134;
  const cValX = margin + 154;

  doc.setFillColor(241, 245, 249);
  doc.setDrawColor(203, 213, 225);
  doc.rect(margin, p2Y, contentWidth, 7, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7);
  doc.setTextColor(51, 65, 85);
  doc.text('COMMODITY DESCRIPTION', cDescX + 4, p2Y + 4.8);
  doc.text('HS / TARIFF CODE', cHsX + 15, p2Y + 4.8, { align: 'center' });
  doc.text('QTY / UNITS', cQtyX + 12, p2Y + 4.8, { align: 'center' });
  doc.text('NET WT', cWtX + 10, p2Y + 4.8, { align: 'center' });
  doc.text('DECLARED (GBP)', cValX + 24, p2Y + 4.8, { align: 'right' });

  p2Y += 7;

  const customsData = [
    {
      title: '1. STEM Educational Building Blocks',
      detail: 'Molded plastic interlocking bricks & STEM sets',
      hs: '9503.00.35',
      qty: '120 Sets',
      wt: '85.0 kg',
      val: '£ 1,500.00'
    },
    {
      title: '2. Die-Cast Toy Vehicles & Race Tracks',
      detail: 'Scale metal alloy cars with plastic track outfits',
      hs: '9503.00.70',
      qty: '90 Outfits',
      wt: '90.0 kg',
      val: '£ 1,600.00'
    },
    {
      title: '3. Plush Stuffed Toys & Animals',
      detail: 'Fabric plush figures (non-electrical / non-battery)',
      hs: '9503.00.41',
      qty: '140 Pcs',
      wt: '75.0 kg',
      val: '£ 1,400.00'
    }
  ];

  customsData.forEach((item, index) => {
    const rH = 9.5;
    if (index % 2 === 0) {
      doc.setFillColor(255, 255, 255);
    } else {
      doc.setFillColor(248, 250, 252);
    }
    doc.rect(margin, p2Y, contentWidth, rH, 'FD');

    // Title & Detail
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7.5);
    doc.setTextColor(15, 23, 42);
    doc.text(item.title, cDescX + 4, p2Y + 4);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(6.5);
    doc.setTextColor(100, 116, 139);
    doc.text(item.detail, cDescX + 4, p2Y + 7.5);

    // HS Code Badge
    doc.setFont('courier', 'bold');
    doc.setFontSize(8);
    doc.setTextColor(14, 165, 233);
    doc.text(item.hs, cHsX + 15, p2Y + 5.8, { align: 'center' });

    // Qty, Wt, Val
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.setTextColor(30, 41, 59);
    doc.text(item.qty, cQtyX + 12, p2Y + 5.8, { align: 'center' });
    doc.text(item.wt, cWtX + 10, p2Y + 5.8, { align: 'center' });

    doc.setFont('courier', 'bold');
    doc.text(item.val, cValX + 24, p2Y + 5.8, { align: 'right' });

    p2Y += rH;
  });

  // Table Aggregate Row
  doc.setFillColor(15, 23, 42);
  doc.rect(margin, p2Y, contentWidth, 8, 'F');

  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.text('TOTAL CONSIGNMENT AGGREGATE:', cDescX + 4, p2Y + 5.2);
  doc.text('350 Units', cQtyX + 12, p2Y + 5.2, { align: 'center' });
  doc.text('250.0 kg', cWtX + 10, p2Y + 5.2, { align: 'center' });

  doc.setTextColor(56, 189, 248);
  doc.setFont('courier', 'bold');
  doc.setFontSize(8.5);
  doc.text('£ 4,500.00', cValX + 24, p2Y + 5.2, { align: 'right' });

  p2Y += 14;

  // Packaging Specifications Card
  doc.setFillColor(248, 250, 252);
  doc.setDrawColor(226, 232, 240);
  doc.roundedRect(margin, p2Y, contentWidth, 30, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(15, 23, 42);
  doc.text('PACKAGING & VOLUMETRIC METRICS', margin + 4, p2Y + 5.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7.5);
  doc.setTextColor(71, 85, 105);
  doc.text('• Package Breakdown: 10 Corrugated Export Master Cartons (Numbered Box #1 through Box #10)', margin + 4, p2Y + 11.5);
  doc.text('• Unit Dimensions: 60 cm (L) x 40 cm (W) x 40 cm (H) per carton  |  Individual Volume: 0.096 CBM', margin + 4, p2Y + 17);
  doc.text('• Total Cubic Volume: 0.96 CBM  |  Volumetric Weight: 192.0 kg  |  Chargeable Weight: 250.0 kg', margin + 4, p2Y + 22.5);

  p2Y += 36;

  // Declaration & Legal Stamp Block
  doc.setFillColor(241, 245, 249);
  doc.setDrawColor(203, 213, 225);
  doc.roundedRect(margin, p2Y, contentWidth, 34, 2, 2, 'FD');

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(15, 23, 42);
  doc.text('CUSTOMS DECLARATION & SAFETY CONFORMITY CERTIFICATION', margin + 4, p2Y + 5.5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(51, 65, 85);
  doc.text('I hereby certify on behalf of Drive Logistics UK that the particulars stated above are true and accurate.', margin + 4, p2Y + 11);
  doc.text('The shipment contains genuine commercial goods, strictly non-hazardous, without restricted lithium batteries, and fully compliant with UK/UAE standards.', margin + 4, p2Y + 16, { maxWidth: contentWidth - 8 });

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7.5);
  doc.setTextColor(15, 23, 42);
  doc.text('Signatory: Drive Logistics UK - Customs Brokerage Team', margin + 4, p2Y + 26);
  doc.text('Entry Ref: PDF 148144 / EXP-2026-AE', margin + 4, p2Y + 30);

  // Status Badge (Right)
  doc.setFillColor(16, 185, 129);
  doc.roundedRect(endX - 60, p2Y + 22, 56, 8, 1.5, 1.5, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(7);
  doc.text('CUSTOMS PRE-CLEARED', endX - 32, p2Y + 27.2, { align: 'center' });

  // Footer Page 2
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(7);
  doc.setTextColor(148, 163, 184);
  doc.text('Drive Logistics UK  |  Declaration Ref: PDF 148144  |  Page 2 of 2', margin, 290);
  doc.text('UK-UAE Official Customs Declaration & Manifest', endX, 290, { align: 'right' });

  // Write outputs
  const downloadsDir = 'C:\\Users\\USER\\Downloads';
  const out1 = path.join(downloadsDir, 'PDF 148144.pdf');
  const out2 = path.join(downloadsDir, '148144.pdf');

  const pdfBytes = doc.output('arraybuffer');
  const buffer = Buffer.from(pdfBytes);

  fs.writeFileSync(out1, buffer);
  fs.writeFileSync(out2, buffer);

  console.log('✅ Generated refined PDF at:');
  console.log('  -> ' + out1);
  console.log('  -> ' + out2);
}

generateProfessionalPdf();
