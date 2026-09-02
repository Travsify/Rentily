import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Inspection } from '../types';
import { NotificationDispatcher } from '../services/notificationDispatcher';
import { AdminDataStore } from '../services/adminDataStore';

export async function getInspections(_req: Request, res: Response) {
  try {
    // Try Supabase first
    let supabaseInsps: Inspection[] = [];
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('inspections')
          .select('*, properties(*)')
          .order('scheduled_date', { ascending: false });

        if (!error && data && data.length > 0) {
          supabaseInsps = data.map((row: any) => ({
            id: row.id,
            propertyId: row.property_id,
            propertyTitle: row.properties?.title || 'Property',
            propertyAddress: row.properties ? `${row.properties.address}, ${row.properties.neighborhood}` : '',
            prospectId: row.prospect_id,
            prospectName: row.prospect_name || 'Prospective Tenant',
            prospectPhone: row.prospect_phone || '+234 812 345 6789',
            ownerId: row.owner_id,
            ownerName: row.owner_name || 'Property Owner',
            ownerPhone: row.owner_phone || '+234 803 000 0000',
            scheduledDate: row.scheduled_date,
            scheduledTimeSlot: row.scheduled_time_slot,
            inspectionPassCode: row.inspection_pass_code,
            status: row.status,
            prospectNotes: row.prospect_notes,
            ownerNotes: row.owner_notes,
            createdAt: row.created_at
          }));
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore
    const storeInsps = AdminDataStore.getInspections();

    if (supabaseInsps.length > 0) {
      const supabaseIds = new Set(supabaseInsps.map(i => i.id));
      const extraStore = storeInsps.filter(i => !supabaseIds.has(i.id));
      return res.json([...supabaseInsps, ...extraStore]);
    }

    return res.json(storeInsps);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function bookInspection(req: Request, res: Response) {
  try {
    const body = req.body;
    const passCode = Math.floor(100000 + Math.random() * 900000).toString();
    const now = new Date().toISOString();

    const inspectionRecord: Inspection = {
      id: `insp_${Date.now()}`,
      propertyId: body.propertyId || 'unknown',
      propertyTitle: body.propertyTitle || 'Property Inspection',
      propertyAddress: body.propertyAddress || '',
      prospectId: body.prospectId || `user_${Date.now()}`,
      prospectName: body.prospectName || 'Prospective Tenant',
      prospectPhone: body.prospectPhone || '',
      ownerId: body.ownerId || 'owner_unknown',
      ownerName: body.ownerName || 'Property Owner',
      ownerPhone: body.ownerPhone || '',
      scheduledDate: body.scheduledDate,
      scheduledTimeSlot: body.scheduledTimeSlot || '11:00 AM - 12:00 PM',
      inspectionPassCode: passCode,
      status: 'pending_owner',
      prospectNotes: body.prospectNotes,
      createdAt: now,
    };

    // Try Supabase first
    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('inspections')
          .insert({
            property_id: body.propertyId,
            prospect_id: body.prospectId || '00000000-0000-0000-0000-000000000002',
            owner_id: body.ownerId || '00000000-0000-0000-0000-000000000001',
            scheduled_date: body.scheduledDate,
            scheduled_time_slot: body.scheduledTimeSlot || '11:00 AM - 12:00 PM',
            inspection_pass_code: passCode,
            status: 'pending_owner',
            prospect_notes: body.prospectNotes
          })
          .select()
          .single();

        if (!error && data) {
          AdminDataStore.addInspection({ ...inspectionRecord, id: data.id });
        }
      } catch (_) {}
    } else {
      AdminDataStore.addInspection(inspectionRecord);
    }

    // Dispatch notification
    if (body.email || body.prospectEmail) {
      NotificationDispatcher.dispatch({
        userId: body.prospectId,
        email: body.email || body.prospectEmail,
        userName: body.prospectName,
        title: `Gate Pass: 6-Digit Code for Inspection (${body.scheduledDate})`,
        category: 'inspection',
        message: `Your property walkthrough inspection has been registered. Present this 6-digit gate code at the estate security gate.`,
        metadata: {
          gateCode: passCode,
          propertyTitle: body.propertyTitle || 'Inspected Property',
          date: `${body.scheduledDate} (${body.scheduledTimeSlot || '11:00 AM'})`
        }
      });
    }

    res.status(201).json({
      success: true,
      inspectionPassCode: passCode,
      message: `Inspection scheduled for ${body.scheduledDate}. Your 6-digit gate pass is: ${passCode}`
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updateInspectionStatus(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status, ownerNotes, rescheduledDate } = req.body;

    // Try Supabase
    if (supabase) {
      try {
        const updateData: any = { status };
        if (ownerNotes) updateData.owner_notes = ownerNotes;
        if (rescheduledDate) updateData.scheduled_date = rescheduledDate;

        const { data, error } = await supabase
          .from('inspections')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

        if (!error && data) {
          AdminDataStore.updateInspectionStatus(id, status, ownerNotes);
          return res.json(data);
        }
      } catch (_) {}
    }

    // Fallback: AdminDataStore only
    const updated = AdminDataStore.updateInspectionStatus(id, status, ownerNotes);
    if (!updated) return res.status(404).json({ error: 'Inspection not found' });
    res.json(updated);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
