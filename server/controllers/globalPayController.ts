import type { Request, Response } from 'express';
import { GlobalPayService } from '../services/globalPayService';
import { supabase } from '../supabaseClient';

/**
 * 1. Get Global Pay Public Configuration & Supported Corridors
 */
export async function getGlobalPayConfig(_req: Request, res: Response) {
  try {
    const config = GlobalPayService.getConfig();
    return res.status(200).json({
      status: true,
      data: {
        featureEnabled: config.featureEnabled,
        supportedCurrencies: config.supportedCurrencies,
        corridorFeesNgn: config.corridorFeesNgn,
        tuitionSemesterLimitUsd: config.tuitionSemesterLimitUsd,
        supplierInvoiceLimitUsd: config.supplierInvoiceLimitUsd,
        corridors: [
          {
            currency: 'GBP',
            country: 'United Kingdom',
            rail: 'Faster Payments (FPS)',
            processingTime: 'Instant - 2 Hours',
            flatFeeNgn: config.corridorFeesNgn.gbpFpsNgn
          },
          {
            currency: 'EUR',
            country: 'Eurozone (36 SEPA Countries)',
            rail: 'SEPA / SEPA Instant',
            processingTime: 'Same Day (Instant)',
            flatFeeNgn: config.corridorFeesNgn.eurSepaNgn
          },
          {
            currency: 'USD',
            country: 'United States',
            rail: 'Fedwire / ACH',
            processingTime: 'Same Day - 24 Hours',
            flatFeeNgn: config.corridorFeesNgn.usdWireNgn
          },
          {
            currency: 'CAD',
            country: 'Canada',
            rail: 'EFT / Interac Direct',
            processingTime: 'Same Day - 24 Hours',
            flatFeeNgn: config.corridorFeesNgn.cadEftNgn
          },
          {
            currency: 'KES',
            country: 'Kenya',
            rail: 'Safaricom M-Pesa / Mobile Money',
            processingTime: 'Instant (Under 5 Mins)',
            flatFeeNgn: config.corridorFeesNgn.momoNgn || 2500
          },
          {
            currency: 'GHS',
            country: 'Ghana',
            rail: 'MTN MoMo / Vodafone Cash',
            processingTime: 'Instant (Under 5 Mins)',
            flatFeeNgn: config.corridorFeesNgn.momoNgn || 2500
          },
          {
            currency: 'ZAR',
            country: 'South Africa',
            rail: 'EFT Domestic Clearing',
            processingTime: 'Same Day - 24 Hours',
            flatFeeNgn: 4000
          },
          {
            currency: 'AED',
            country: 'United Arab Emirates (Dubai)',
            rail: 'UAE Central Bank Clearing',
            processingTime: '24 Hours',
            flatFeeNgn: 6500
          },
          {
            currency: 'USD',
            country: 'Global International (150+ Countries: China, Turkey, etc.)',
            rail: 'SWIFT International Wire',
            processingTime: '24 - 48 Hours',
            flatFeeNgn: config.corridorFeesNgn.usdSwiftNgn
          }
        ]
      }
    });
  } catch (err: any) {
    return res.status(500).json({ status: false, error: err.message });
  }
}

/**
 * 2. Generate Guaranteed 15-Minute FX Quote
 */
export async function getQuote(req: Request, res: Response) {
  try {
    const { destinationCurrency, destinationAmount, destinationCountry, preferredScheme } = req.body;

    if (!destinationCurrency || !destinationAmount) {
      return res.status(400).json({
        status: false,
        error: 'destinationCurrency and destinationAmount are required.'
      });
    }

    const quote = await GlobalPayService.generateQuote({
      destinationCurrency: destinationCurrency.toUpperCase(),
      destinationAmount: Number(destinationAmount),
      destinationCountry,
      preferredScheme
    });

    return res.status(200).json({
      status: true,
      data: quote,
      message: 'Guaranteed 15-minute FX quote generated.'
    });
  } catch (err: any) {
    return res.status(400).json({ status: false, error: err.message });
  }
}

/**
 * 3. Submit and Authorize Global Payout Order
 */
export async function submitGlobalPayout(req: Request, res: Response) {
  try {
    const authUser = (req as any).user;
    const userId = authUser?.id || req.body.userId;
    const userEmail = authUser?.email || req.body.userEmail;

    if (!userId) {
      return res.status(401).json({ status: false, error: 'User must be authenticated.' });
    }

    const {
      quoteReference,
      orderType,
      transferPurpose,
      beneficiary,
      studentName,
      studentMatricId,
      institutionName,
      semesterSession,
      invoiceNumber,
      poNumber,
      goodsDescription,
      bursarEmail,
      documentUrl,
      pin
    } = req.body;

    if (!quoteReference || !orderType || !beneficiary) {
      return res.status(400).json({
        status: false,
        error: 'quoteReference, orderType, and beneficiary details are required.'
      });
    }

    // Specific order validation
    if (orderType === 'tuition') {
      if (!studentName?.trim() || !studentMatricId?.trim() || !institutionName?.trim()) {
        return res.status(400).json({
          status: false,
          error: 'Tuition payouts require verified Student Name, Matriculation ID, and Institution Name.'
        });
      }
    } else if (orderType === 'supplier') {
      if (!invoiceNumber?.trim()) {
        return res.status(400).json({
          status: false,
          error: 'Supplier commercial payouts require a valid Invoice Number.'
        });
      }
    }

    // Beneficiary account validation
    if (!beneficiary.accountNumberOrIban?.trim() || !beneficiary.name?.trim()) {
      return res.status(400).json({
        status: false,
        error: 'Beneficiary account number / IBAN and beneficiary name are mandatory.'
      });
    }

    // Verify PIN if user has one configured
    if (supabase) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('transaction_pin, full_name, email')
        .eq('id', userId)
        .single();

      if (profile?.transaction_pin) {
        if (!pin || profile.transaction_pin !== pin.trim()) {
          return res.status(403).json({ status: false, error: 'Incorrect or missing 4-digit transaction PIN.' });
        }
      }
    }

    const order = await GlobalPayService.submitOrder({
      userId,
      userEmail,
      quoteReference,
      orderType,
      transferPurpose,
      beneficiary,
      studentName,
      studentMatricId,
      institutionName,
      semesterSession,
      invoiceNumber,
      poNumber,
      goodsDescription,
      bursarEmail,
      documentUrl
    });

    return res.status(201).json({
      status: true,
      data: order,
      message: 'Cross-border payout submitted and pre-auth hold secured.'
    });
  } catch (err: any) {
    return res.status(400).json({ status: false, error: err.message });
  }
}

/**
 * 4. List User's Global Orders
 */
export async function getUserOrders(req: Request, res: Response) {
  try {
    const userId = (req as any).user?.id || req.query.userId;
    if (!userId) {
      return res.status(401).json({ status: false, error: 'User must be authenticated.' });
    }

    const orders = await GlobalPayService.listOrders(String(userId));
    return res.status(200).json({
      status: true,
      data: orders
    });
  } catch (err: any) {
    return res.status(500).json({ status: false, error: err.message });
  }
}

/**
 * 5. Track Order by Reference
 */
export async function trackOrder(req: Request, res: Response) {
  try {
    const reference = req.params.reference || (req.query.reference as string);
    if (!reference) {
      return res.status(400).json({ status: false, error: 'Reference parameter is required.' });
    }

    const order = await GlobalPayService.getOrder(reference);
    if (!order) {
      return res.status(404).json({ status: false, error: 'Order not found.' });
    }

    return res.status(200).json({
      status: true,
      data: order
    });
  } catch (err: any) {
    return res.status(500).json({ status: false, error: err.message });
  }
}
