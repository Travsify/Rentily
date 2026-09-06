import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Inspection } from '../types';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { AdminDataStore } from '../services/adminDataStore';

export async function getInspections(req: Request, res: Response) {
  try {
    const { email, userId, propertyId, status } = req.query;
    const cleanEmail = email ? String(email).toLowerCase().trim() : '';

    // Primary: AdminDataStore
    let storeInsps = AdminDataStore.getInspections();

    // Secondary: Supabase (if available)
    if (supabase) {
      try {
        let query = supabase
          .from('inspections')
          .select('*, properties(*)')
          .order('scheduled_date', { ascending: false });

        if (status) query = query.eq('status', status);

        const { data, error } = await query;
        if (!error && data && data.length > 0) {
          const supabaseInsps: Inspection[] = data.map((row: any) => ({
            id: row.id,
            propertyId: row.property_id,
            propertyTitle: row.properties?.title || 'Property',
            propertyAddress: row.properties ? `${row.properties.address}, ${row.properties.neighborhood}` : '',
            prospectId: row.prospect_id,
            prospectName: row.prospect_name || 'Prospective Tenant',
            prospectEmail: (row.prospect_email || row.renter_email || row.email || '').toLowerCase().trim(),
            prospectPhone: row.prospect_phone || '+234 812 345 6789',
            ownerId: row.owner_id,
            ownerName: row.owner_name || 'Property Owner',
            ownerEmail: (row.owner_email || '').toLowerCase().trim(),
            ownerPhone: row.owner_phone || '+234 803 000 0000',
            scheduledDate: row.scheduled_date,
            scheduledTimeSlot: row.scheduled_time_slot,
            inspectionPassCode: row.inspection_pass_code,
            status: row.status,
            prospectNotes: row.prospect_notes,
            ownerNotes: row.owner_notes,
            createdAt: row.created_at
          }));

          const storeIds = new Set(storeInsps.map(i => i.id));
          const missing = supabaseInsps.filter(i => !storeIds.has(i.id));
          storeInsps = [...storeInsps, ...missing];
        }
      } catch (_) {}
    }

    // Apply filters if requested by Flutter app
    if (cleanEmail) {
      storeInsps = storeInsps.filter(i =>
        i.prospectEmail?.toLowerCase?.() === cleanEmail ||
        i.ownerEmail?.toLowerCase?.() === cleanEmail ||
        (i as any).email?.toLowerCase?.() === cleanEmail ||
        i.prospectName.toLowerCase().includes(cleanEmail) ||
        i.ownerName.toLowerCase().includes(cleanEmail) ||
        i.prospectPhone.includes(cleanEmail)
      );
    }
    if (userId) {
      storeInsps = storeInsps.filter(i => i.prospectId === userId || i.ownerId === userId);
    }
    if (propertyId) {
      storeInsps = storeInsps.filter(i => i.propertyId === propertyId);
    }
    if (status) {
      storeInsps = storeInsps.filter(i => i.status === status);
    }

    res.json(storeInsps);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function bookInspection(req: Request, res: Response) {
  try {
    const body = req.body;
    const passCode = Math.floor(100000 + Math.random() * 900000).toString();
    const now = new Date().toISOString();
    const newId = body.id || `insp_${Date.now()}`;

    const prospectEmail = (body.email || body.prospectEmail || '').toString().toLowerCase().trim();
    let ownerEmail = (body.ownerEmail || '').toString().toLowerCase().trim();
    let propOwnerId = body.ownerId || '';
    let propOwnerName = body.ownerName || '';
    let propOwnerPhone = body.ownerPhone || '';
    let propTitle = body.propertyTitle || '';
    let propAddress = body.propertyAddress || '';

    // Auto-resolve property host/owner from AdminDataStore or Supabase
    if (body.propertyId && (!propOwnerId || propOwnerId === 'owner_direct')) {
      const propFromStore = AdminDataStore.getProperties().find(p => p.id === body.propertyId);
      if (propFromStore) {
        propOwnerId = (propFromStore as any).partnerId || propFromStore.ownerId || propOwnerId;
        propOwnerName = (propFromStore as any).partnerBusinessName || (propFromStore as any).partnerName || propFromStore.ownerName || propOwnerName;
        if (!ownerEmail && propFromStore.ownerEmail) ownerEmail = propFromStore.ownerEmail.toLowerCase().trim();
        if (!propOwnerPhone && propFromStore.ownerPhone) propOwnerPhone = propFromStore.ownerPhone;
        if (!propTitle && propFromStore.title) propTitle = propFromStore.title;
        if (!propAddress && propFromStore.address) propAddress = propFromStore.address;
      } else if (supabase) {
        try {
          const { data: pData } = await supabase.from('properties').select('*').eq('id', body.propertyId).single();
          if (pData) {
            propOwnerId = pData.partner_id || pData.owner_id || propOwnerId;
            propOwnerName = pData.partner_business_name || pData.partner_name || pData.owner_name || propOwnerName;
            if (!ownerEmail && pData.owner_email) ownerEmail = pData.owner_email.toLowerCase().trim();
            if (!propOwnerPhone && pData.owner_phone) propOwnerPhone = pData.owner_phone;
            if (!propTitle && pData.title) propTitle = pData.title;
            if (!propAddress && pData.address) propAddress = pData.address;
          }
        } catch (_) {}
      }
    }

    if (!propOwnerId) propOwnerId = 'owner_direct';
    if (!propOwnerName) propOwnerName = 'Property Landlord';
    if (!propTitle) propTitle = 'Property Walkthrough Inspection';

    const inspectionRecord: Inspection = {
      id: newId,
      propertyId: body.propertyId || 'unknown',
      propertyTitle: propTitle,
      propertyAddress: propAddress,
      prospectId: body.prospectId || `usr_${Date.now()}`,
      prospectName: body.prospectName || 'Prospective Tenant',
      prospectEmail: prospectEmail,
      prospectPhone: body.prospectPhone || '',
      ownerId: propOwnerId,
      ownerName: propOwnerName,
      ownerEmail: ownerEmail,
      ownerPhone: propOwnerPhone,
      scheduledDate: body.scheduledDate || new Date().toISOString().split('T')[0],
      scheduledTimeSlot: body.scheduledTimeSlot || '11:00 AM - 12:00 PM',
      inspectionPassCode: passCode,
      status: 'pending_owner',
      prospectNotes: body.prospectNotes,
      createdAt: now,
    };

    // Always save to AdminDataStore so Admin Inspections Tab immediately shows it
    AdminDataStore.addInspection(inspectionRecord);

    // Also persist in Supabase if available
    if (supabase) {
      try {
        await supabase
          .from('inspections')
          .insert({
            id: inspectionRecord.id,
            property_id: body.propertyId,
            prospect_id: inspectionRecord.prospectId,
            owner_id: inspectionRecord.ownerId,
            scheduled_date: inspectionRecord.scheduledDate,
            scheduled_time_slot: inspectionRecord.scheduledTimeSlot,
            inspection_pass_code: passCode,
            status: 'pending_owner',
            prospect_notes: body.prospectNotes
          });
      } catch (_) {}
    }

    // Dispatch notifications to both Tenant and Host (Landlord / Partner)
    const recipientEmail = body.email || body.prospectEmail;
    if (recipientEmail) {
      NotificationDispatcher.dispatch({
        userId: inspectionRecord.prospectId,
        email: recipientEmail,
        userName: inspectionRecord.prospectName,
        title: `Gate Pass: 6-Digit Security Code (${inspectionRecord.scheduledDate})`,
        category: 'inspection',
        message: `Your property walkthrough inspection has been booked. Present this 6-digit gate code to the security guards.`,
        metadata: {
          gateCode: passCode,
          propertyTitle: inspectionRecord.propertyTitle,
          date: `${inspectionRecord.scheduledDate} (${inspectionRecord.scheduledTimeSlot})`
        }
      });
    }

    if (ownerEmail || (propOwnerId && propOwnerId !== 'owner_direct')) {
      NotificationDispatcher.dispatch({
        userId: propOwnerId,
        email: ownerEmail || 'host@myrentilly.com',
        userName: propOwnerName,
        title: `🔑 New Inspection Request: ${inspectionRecord.propertyTitle}`,
        category: 'inspection',
        message: `${inspectionRecord.prospectName} requested a walkthrough on ${inspectionRecord.scheduledDate} (${inspectionRecord.scheduledTimeSlot}). Pass: ${passCode}`,
        metadata: {
          inspectionId: newId,
          gateCode: passCode,
          propertyTitle: inspectionRecord.propertyTitle,
          prospectName: inspectionRecord.prospectName,
          date: `${inspectionRecord.scheduledDate} (${inspectionRecord.scheduledTimeSlot})`
        }
      });
    }

    res.status(201).json({
      success: true,
      inspectionPassCode: passCode,
      inspection: inspectionRecord,
      message: `Inspection scheduled for ${inspectionRecord.scheduledDate}. Your 6-digit gate pass is: ${passCode}`
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updateInspectionStatus(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status, ownerNotes, rescheduledDate } = req.body;

    // Update in AdminDataStore
    const updated = AdminDataStore.updateInspectionStatus(id, status, ownerNotes);

    // Also update in Supabase
    if (supabase) {
      try {
        const updateData: any = { status };
        if (ownerNotes) updateData.owner_notes = ownerNotes;
        if (rescheduledDate) updateData.scheduled_date = rescheduledDate;

        await supabase
          .from('inspections')
          .update(updateData)
          .eq('id', id);
      } catch (_) {}
    }

    if (!updated) return res.status(404).json({ error: 'Inspection not found' });

    // Dispatch notification to prospect if email is available
    const prospectEmail = (updated as any).email || (updated as any).prospectEmail || `${updated.prospectId}@myrentilly.com`;
    if (status === 'confirmed') {
      NotificationDispatcher.dispatch({
        userId: updated.prospectId,
        email: prospectEmail,
        userName: updated.prospectName,
        title: `Walkthrough Inspection Confirmed 🔑✅`,
        category: 'inspection',
        message: `Your physical inspection for "${updated.propertyTitle}" has been confirmed for ${updated.scheduledDate} (${updated.scheduledTimeSlot}). Gate pass code: ${updated.inspectionPassCode}.`,
        metadata: {
          gateCode: updated.inspectionPassCode,
          propertyTitle: updated.propertyTitle,
          date: updated.scheduledDate
        }
      });
    } else if (status === 'rescheduled') {
      NotificationDispatcher.dispatch({
        userId: updated.prospectId,
        email: prospectEmail,
        userName: updated.prospectName,
        title: `Inspection Rescheduled 📅`,
        category: 'inspection',
        message: `Your walkthrough inspection has been rescheduled to ${rescheduledDate || updated.scheduledDate}. Gate code remains: ${updated.inspectionPassCode}.`,
        metadata: {
          gateCode: updated.inspectionPassCode,
          newDate: rescheduledDate || updated.scheduledDate
        }
      });
    }

    res.json(updated);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
