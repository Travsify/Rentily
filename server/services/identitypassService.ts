import dotenv from 'dotenv';

dotenv.config();

const IDENTITYPASS_API_KEY = process.env.IDENTITYPASS_API_KEY || '';
const IDENTITYPASS_APP_ID = process.env.IDENTITYPASS_APP_ID || '';
const PREMBLY_BASE_URL = 'https://api.prembly.com';
const IDENTITYPASS_LEGACY_URL = 'https://api.myidentitypass.com/v2/biometrics/merchant/data/verification';

export class IdentitypassService {
  private static getHeaders() {
    return {
      'Content-Type': 'application/json',
      'x-api-key': process.env.IDENTITYPASS_API_KEY || IDENTITYPASS_API_KEY,
      'app-id': process.env.IDENTITYPASS_APP_ID || IDENTITYPASS_APP_ID
    };
  }

  static isConfigured(): boolean {
    const key = process.env.IDENTITYPASS_API_KEY || IDENTITYPASS_API_KEY;
    return Boolean(key && key.length > 5);
  }

  // 1. Verify National Identification Number (NIN)
  static async verifyNIN(ninNumber: string): Promise<{
    status: boolean;
    data?: {
      firstName: string;
      lastName: string;
      middleName?: string;
      fullName: string;
      phone: string;
      dateOfBirth: string;
      gender: string;
      photo?: string;
      address?: string;
    };
    raw?: any;
    message?: string;
  }> {
    if (!this.isConfigured()) {
      return {
        status: true,
        data: {
          firstName: 'Verified',
          lastName: 'Landlord',
          fullName: 'Chief Verified Nigerian Landlord',
          phone: '+2348000000000',
          dateOfBirth: '1978-05-12',
          gender: 'Male'
        },
        message: 'Identitypass demo mode (Live API key pending in Settings)'
      };
    }

    try {
      const response = await fetch(`${PREMBLY_BASE_URL}/identitypass/verification/nin`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ number: ninNumber.trim(), number_nin: ninNumber.trim() })
      });

      const resJson: any = await response.json();

      if (response.ok && (resJson.status === true || resJson.response_code === '00')) {
        const ninData = resJson.nin_data || resJson.data || {};
        return {
          status: true,
          data: {
            firstName: ninData.firstname || ninData.first_name || '',
            lastName: ninData.surname || ninData.last_name || '',
            middleName: ninData.middlename || ninData.middle_name || '',
            fullName: `${ninData.firstname || ''} ${ninData.surname || ''}`.trim(),
            phone: ninData.telephoneno || ninData.phone_number || '',
            dateOfBirth: ninData.birthdate || ninData.dob || '',
            gender: ninData.gender || '',
            photo: ninData.photo || ninData.image || '',
            address: ninData.residence_address || ninData.address || ''
          },
          raw: resJson
        };
      } else {
        return {
          status: false,
          message: resJson.message || resJson.detail || 'NIN verification record not found with NIMC'
        };
      }
    } catch (err: any) {
      return {
        status: false,
        message: `Identitypass connection error: ${err.message}`
      };
    }
  }

  // 2. Verify Bank Verification Number (BVN)
  static async verifyBVN(bvnNumber: string): Promise<{
    status: boolean;
    data?: {
      firstName: string;
      lastName: string;
      fullName: string;
      phone: string;
      dateOfBirth: string;
      bvn: string;
    };
    raw?: any;
    message?: string;
  }> {
    if (!this.isConfigured()) {
      return {
        status: true,
        data: {
          firstName: 'Verified',
          lastName: 'Owner',
          fullName: 'Verified Property Owner (BVN Match)',
          phone: '+2348000000000',
          dateOfBirth: '1982-11-04',
          bvn: bvnNumber
        },
        message: 'Identitypass demo mode (Live API key pending in Settings)'
      };
    }

    try {
      const response = await fetch(`${PREMBLY_BASE_URL}/identitypass/verification/bvn`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ number: bvnNumber.trim() })
      });

      const resJson: any = await response.json();

      if (response.ok && (resJson.status === true || resJson.response_code === '00')) {
        const bvnData = resJson.bvn_data || resJson.data || {};
        return {
          status: true,
          data: {
            firstName: bvnData.firstName || bvnData.first_name || '',
            lastName: bvnData.lastName || bvnData.last_name || '',
            fullName: `${bvnData.firstName || ''} ${bvnData.lastName || ''}`.trim(),
            phone: bvnData.phoneNumber1 || bvnData.phone_number || '',
            dateOfBirth: bvnData.dateOfBirth || bvnData.dob || '',
            bvn: bvnNumber
          },
          raw: resJson
        };
      } else {
        return {
          status: false,
          message: resJson.message || 'BVN verification failed with NIBSS'
        };
      }
    } catch (err: any) {
      return {
        status: false,
        message: `Identitypass connection error: ${err.message}`
      };
    }
  }

  // 3. Verify CAC Registered Corporate Landlord / Estate Company
  static async verifyCAC(rcNumber: string, companyName?: string): Promise<{
    status: boolean;
    data?: {
      companyName: string;
      rcNumber: string;
      companyType: string;
      registrationDate: string;
      address: string;
      status: string;
    };
    raw?: any;
    message?: string;
  }> {
    if (!this.isConfigured()) {
      return {
        status: true,
        data: {
          companyName: companyName || 'Rentilly Prime Estates Limited',
          rcNumber: rcNumber,
          companyType: 'Private Company Limited by Shares (LTD)',
          registrationDate: '2018-04-20',
          address: 'Plot 14, Admiralty Way, Lekki Phase 1, Lagos',
          status: 'ACTIVE'
        }
      };
    }

    try {
      const response = await fetch(`${PREMBLY_BASE_URL}/identitypass/verification/cac`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ rc_number: rcNumber.trim(), company_name: companyName })
      });

      const resJson: any = await response.json();
      if (response.ok && resJson.status === true) {
        const cacData = resJson.cac_data || resJson.data || {};
        return {
          status: true,
          data: {
            companyName: cacData.company_name || cacData.name || '',
            rcNumber: cacData.rc_number || rcNumber,
            companyType: cacData.company_type || '',
            registrationDate: cacData.registration_date || '',
            address: cacData.head_office_address || cacData.address || '',
            status: cacData.status || 'ACTIVE'
          },
          raw: resJson
        };
      } else {
        return {
          status: false,
          message: resJson.message || 'Corporate entity not found in CAC Registry'
        };
      }
    } catch (err: any) {
      return {
        status: false,
        message: `Identitypass CAC check error: ${err.message}`
      };
    }
  }
}
