import type { Request, Response } from 'express';
import { IdentitypassService } from '../services/identitypassService';
import { supabase } from '../supabaseClient';

export async function verifyNIN(req: Request, res: Response) {
  try {
    const { nin, propertyId, ownerId } = req.body;
    if (!nin) {
      return res.status(400).json({ error: 'NIN number is required' });
    }

    const result = await IdentitypassService.verifyNIN(nin);

    // Save verification audit log in Supabase
    if (supabase && result.status) {
      await supabase.from('identity_verifications').insert({
        property_id: propertyId || null,
        user_id: ownerId || null,
        verification_type: 'nin',
        id_number: nin,
        full_name_returned: result.data?.fullName || null,
        date_of_birth: result.data?.dateOfBirth || null,
        phone_number_returned: result.data?.phone || null,
        photo_url: result.data?.photo || null,
        raw_response: result.raw || null,
        status: 'verified',
        verified_by_admin: 'Rentilly Automated Prembly Engine'
      });
    }

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function verifyBVN(req: Request, res: Response) {
  try {
    const { bvn, propertyId, ownerId } = req.body;
    if (!bvn) {
      return res.status(400).json({ error: 'BVN number is required' });
    }

    const result = await IdentitypassService.verifyBVN(bvn);

    if (supabase && result.status) {
      await supabase.from('identity_verifications').insert({
        property_id: propertyId || null,
        user_id: ownerId || null,
        verification_type: 'bvn',
        id_number: bvn,
        full_name_returned: result.data?.fullName || null,
        date_of_birth: result.data?.dateOfBirth || null,
        phone_number_returned: result.data?.phone || null,
        raw_response: result.raw || null,
        status: 'verified',
        verified_by_admin: 'Rentilly Automated Prembly Engine'
      });
    }

    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}

export async function verifyCAC(req: Request, res: Response) {
  try {
    const { rcNumber, companyName } = req.body;
    if (!rcNumber) {
      return res.status(400).json({ error: 'RC / Business Registration Number is required' });
    }

    const result = await IdentitypassService.verifyCAC(rcNumber, companyName);
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
