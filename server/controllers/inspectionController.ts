import type { Request, Response } from 'express';
import { supabase } from '../supabaseClient';
import type { Inspection } from '../types';
import { NotificationDispatcher } from '../services/notificationDispatcher';

export async function getInspections(_req: Request, res: Response) {
  try {
    if (!supabase) return res.json([]);

    const { data, error } = await supabase
      .from('inspections')
      .select('*, properties(*)')
      .order('scheduled_date', { ascending: false });

    if (error) return res.json([]);

    const inspections: Inspection[] = (data || []).map((row: any) => ({
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

    res.json(inspections);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function bookInspection(req: Request, res: Response) {
  try {
    const body = req.body;
    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    // Generate 6-digit gate security pass code
    const passCode = Math.floor(100000 + Math.random() * 900000).toString();

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

    if (error) throw new Error(error.message);

    // Dispatch In-App Alert & Resend HTML Email with 6-Digit Gate Code
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

    res.status(201).json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function updateInspectionStatus(req: Request, res: Response) {
  try {
    const { id } = req.params;
    const { status, ownerNotes } = req.body;

    if (!supabase) return res.status(500).json({ error: 'Database unavailable' });

    const updatePayload: any = {
      status,
      updated_at: new Date().toISOString()
    };
    if (ownerNotes) updatePayload.owner_notes = ownerNotes;

    const { data, error } = await supabase
      .from('inspections')
      .update(updatePayload)
      .eq('id', id)
      .select()
      .single();

    if (error) throw new Error(error.message);
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
