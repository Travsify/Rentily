/**
 * Multi-Carrier Shipping Engine & UK-to-Dubai Rate Comparison
 * Supports: ShipEngine, Shippo, EasyPost, Sendcloud
 */

export interface PackageItem {
  description: string;
  quantity: number;
  unitValue: number;
  currency: string;
  totalValue: number;
  hsCode: string;
  originCountry: string;
  weightKg: number;
}

export interface ParcelPiece {
  boxNumber: number;
  weightKg: number;
  dimensionsCm: {
    length: number;
    width: number;
    height: number;
  };
  volumetricWeightKg: number;
}

export interface ToyShipmentManifest {
  manifestId: string;
  description: string;
  totalActualWeightKg: number;
  totalVolumetricWeightKg: number;
  chargeableWeightKg: number;
  totalDeclaredValueGbp: number;
  totalDeclaredValueAed: number;
  totalDeclaredValueUsd: number;
  packageType: 'multi_piece_cartons' | 'palletized_freight';
  sender: {
    company: string;
    contactName: string;
    addressLine1: string;
    city: string;
    postalCode: string;
    country: string; // 'GB'
    phone: string;
    email: string;
  };
  recipient: {
    company: string;
    contactName: string;
    addressLine1: string;
    district: string;
    city: string;
    postalCode: string;
    country: string; // 'AE'
    phone: string;
    email: string;
  };
  items: PackageItem[];
  packages: ParcelPiece[];
}

export interface CarrierRateQuote {
  provider: 'ShipEngine' | 'Shippo' | 'EasyPost' | 'Sendcloud';
  carrier: string; // 'DHL Express' | 'FedEx' | 'UPS' | 'DPD UK'
  serviceName: string;
  serviceCode: string;
  deliveryDays: string;
  estimatedDeliveryDate: string;
  currency: string;
  baseShippingCostGbp: number;
  fuelSurchargeGbp: number;
  customsClearanceFeeGbp: number;
  totalShippingCostGbp: number;
  totalCostAed: number;
  totalCostUsd: number;
  estimatedUaeCustomsDutyAed: number; // 5% over threshold
  estimatedUaeVatAed: number; // 5% VAT
  isMockData: boolean;
  notes: string;
}

// 250KG Toy Manifest Generator
export function create250kgToyManifest(packageType: 'multi_piece_cartons' | 'palletized_freight' = 'multi_piece_cartons'): ToyShipmentManifest {
  const gbpToAed = 4.75;
  const gbpToUsd = 1.30;
  
  const items: PackageItem[] = [
    {
      description: 'Educational STEM Building Block Sets (Plastic)',
      quantity: 120,
      unitValue: 12.50,
      totalValue: 1500.00,
      currency: 'GBP',
      hsCode: '9503.00.35', // Other toys; reduced-size models and similar recreational models
      originCountry: 'GB',
      weightKg: 85.0
    },
    {
      description: 'Die-Cast Scale Toy Vehicles & Racing Tracks',
      quantity: 90,
      unitValue: 17.78,
      totalValue: 1600.00,
      currency: 'GBP',
      hsCode: '9503.00.70', // Other toys, put up in sets or outfits
      originCountry: 'GB',
      weightKg: 90.0
    },
    {
      description: 'Plush Stuffed Animal Toys (Non-Electronic)',
      quantity: 140,
      unitValue: 10.00,
      totalValue: 1400.00,
      currency: 'GBP',
      hsCode: '9503.00.41', // Stuffed toys representing animals or non-human creatures
      originCountry: 'GB',
      weightKg: 75.0
    }
  ];

  let packages: ParcelPiece[] = [];

  if (packageType === 'multi_piece_cartons') {
    // 10 Master Cartons x 25kg each
    for (let i = 1; i <= 10; i++) {
      const l = 60;
      const w = 40;
      const h = 40;
      // Air courier volumetric divisor = 5000 (standard IATA)
      const volWeight = (l * w * h) / 5000; // 19.2kg
      packages.push({
        boxNumber: i,
        weightKg: 25.0,
        dimensionsCm: { length: l, width: w, height: h },
        volumetricWeightKg: Number(volWeight.toFixed(1))
      });
    }
  } else {
    // 1 Euro Pallet (120x80x160 cm)
    const l = 120;
    const w = 80;
    const h = 160;
    const volWeight = (l * w * h) / 5000; // 307.2kg
    packages.push({
      boxNumber: 1,
      weightKg: 250.0,
      dimensionsCm: { length: l, width: w, height: h },
      volumetricWeightKg: Number(volWeight.toFixed(1))
    });
  }

  const totalActualWeight = packages.reduce((acc, p) => acc + p.weightKg, 0);
  const totalVolumetricWeight = packages.reduce((acc, p) => acc + p.volumetricWeightKg, 0);
  const chargeableWeight = Math.max(totalActualWeight, totalVolumetricWeight);
  const totalDeclaredGbp = items.reduce((acc, item) => acc + item.totalValue, 0);

  return {
    manifestId: `MNF-TOY-${Date.now().toString(36).toUpperCase()}`,
    description: '250kg Commercial Consignment of Children Toys & Games (UK to Dubai)',
    totalActualWeightKg: totalActualWeight,
    totalVolumetricWeightKg: Number(totalVolumetricWeight.toFixed(1)),
    chargeableWeightKg: Number(chargeableWeight.toFixed(1)),
    totalDeclaredValueGbp: totalDeclaredGbp,
    totalDeclaredValueAed: totalDeclaredGbp * gbpToAed,
    totalDeclaredValueUsd: totalDeclaredGbp * gbpToUsd,
    packageType,
    sender: {
      company: 'London Toy Exporters Ltd',
      contactName: 'Operations Dept',
      addressLine1: '142 High Holborn',
      city: 'London',
      postalCode: 'WC1V 6PX',
      country: 'GB',
      phone: '+44 20 7946 0912',
      email: 'export@londontoys.co.uk'
    },
    recipient: {
      company: 'Dubai Fun & Play Distribution LLC',
      contactName: 'Logistics Manager',
      addressLine1: 'Bay Square Building 07, Business Bay',
      district: 'Business Bay',
      city: 'Dubai',
      postalCode: '00000',
      country: 'AE',
      phone: '+971 4 362 7000',
      email: 'imports@dubaifunplay.ae'
    },
    items,
    packages
  };
}

export class ShippingService {
  /**
   * Calculate realistic benchmark rates for 250kg UK -> Dubai
   */
  public static calculateBenchmarkRates(manifest: ToyShipmentManifest, customProvider?: string): CarrierRateQuote[] {
    const chargeableWeight = manifest.chargeableWeightKg;
    const gbpToAed = 4.75;
    const gbpToUsd = 1.30;
    
    // UAE Customs calculation: 5% Duty on CIF Value if value > AED 300 (~£65) + 5% VAT
    const cifValueAed = manifest.totalDeclaredValueAed;
    const estimatedDutyAed = Number((cifValueAed * 0.05).toFixed(2)); // 5% Customs Duty
    const estimatedVatAed = Number(((cifValueAed + estimatedDutyAed) * 0.05).toFixed(2)); // 5% VAT

    const baseQuotes: Array<{
      provider: 'ShipEngine' | 'Shippo' | 'EasyPost' | 'Sendcloud';
      carrier: string;
      serviceName: string;
      serviceCode: string;
      deliveryDays: string;
      ratePerKg: number;
      baseFlat: number;
      fuelPercent: number;
      clearanceFee: number;
      notes: string;
    }> = [
      {
        provider: 'Sendcloud',
        carrier: 'DHL Express',
        serviceName: 'Express Worldwide (UK to UAE)',
        serviceCode: 'dhl_express_worldwide',
        deliveryDays: '2-3 Business Days',
        ratePerKg: 3.45,
        baseFlat: 45.0,
        fuelPercent: 0.18,
        clearanceFee: 15.0,
        notes: 'Includes Paperless Trade (ETD) & direct commercial invoice customs transmission.'
      },
      {
        provider: 'Sendcloud',
        carrier: 'UPS',
        serviceName: 'UPS Express Saver International',
        serviceCode: 'ups_express_saver',
        deliveryDays: '3-4 Business Days',
        ratePerKg: 3.60,
        baseFlat: 40.0,
        fuelPercent: 0.20,
        clearanceFee: 18.0,
        notes: 'UPS pre-negotiated commercial rates via Sendcloud UK account.'
      },
      {
        provider: 'ShipEngine',
        carrier: 'FedEx',
        serviceName: 'FedEx International Priority',
        serviceCode: 'fedex_international_priority',
        deliveryDays: '2-3 Business Days',
        ratePerKg: 3.75,
        baseFlat: 50.0,
        fuelPercent: 0.19,
        clearanceFee: 20.0,
        notes: 'Supports multi-piece commercial consolidation & custom broker assigned.'
      },
      {
        provider: 'ShipEngine',
        carrier: 'DHL Express',
        serviceName: 'DHL Express 12:00 Time Definite',
        serviceCode: 'dhl_express_12',
        deliveryDays: '2 Business Days (Morning Delivery)',
        ratePerKg: 4.10,
        baseFlat: 65.0,
        fuelPercent: 0.18,
        clearanceFee: 15.0,
        notes: 'Time-definite morning delivery to Dubai commercial centers.'
      },
      {
        provider: 'Shippo',
        carrier: 'DHL Express',
        serviceName: 'DHL Express Worldwide via Shippo',
        serviceCode: 'shippo_dhl_worldwide',
        deliveryDays: '2-3 Business Days',
        ratePerKg: 3.50,
        baseFlat: 42.0,
        fuelPercent: 0.18,
        clearanceFee: 15.0,
        notes: 'Instant label generation with Shippo built-in discounted rates.'
      },
      {
        provider: 'Shippo',
        carrier: 'UPS',
        serviceName: 'UPS Expedited Worldwide',
        serviceCode: 'shippo_ups_expedited',
        deliveryDays: '4-5 Business Days',
        ratePerKg: 3.20,
        baseFlat: 38.0,
        fuelPercent: 0.20,
        clearanceFee: 18.0,
        notes: 'Economy air courier option for lower cost on heavier cargo.'
      },
      {
        provider: 'EasyPost',
        carrier: 'FedEx',
        serviceName: 'FedEx International Economy',
        serviceCode: 'easypost_fedex_economy',
        deliveryDays: '4-6 Business Days',
        ratePerKg: 3.15,
        baseFlat: 45.0,
        fuelPercent: 0.19,
        clearanceFee: 20.0,
        notes: 'Cost-effective high-weight consolidation via EasyPost rating engine.'
      },
      {
        provider: 'EasyPost',
        carrier: 'UPS',
        serviceName: 'UPS Worldwide Saver',
        serviceCode: 'easypost_ups_saver',
        deliveryDays: '3-4 Business Days',
        ratePerKg: 3.55,
        baseFlat: 40.0,
        fuelPercent: 0.20,
        clearanceFee: 18.0,
        notes: 'Direct API rate shopping with automatic customs document schema.'
      },
      {
        provider: 'Sendcloud',
        carrier: 'DPD UK',
        serviceName: 'DPD Classic Air International',
        serviceCode: 'dpd_air_classic',
        deliveryDays: '4-6 Business Days',
        ratePerKg: 2.95,
        baseFlat: 35.0,
        fuelPercent: 0.16,
        clearanceFee: 22.0,
        notes: 'European/UK consolidated air forwarding to Dubai.'
      }
    ];

    const targetQuotes = customProvider
      ? baseQuotes.filter(q => q.provider.toLowerCase() === customProvider.toLowerCase())
      : baseQuotes;

    return targetQuotes.map(q => {
      const baseShippingCost = Number((q.baseFlat + (chargeableWeight * q.ratePerKg)).toFixed(2));
      const fuelSurcharge = Number((baseShippingCost * q.fuelPercent).toFixed(2));
      const clearanceFee = q.clearanceFee;
      const totalShippingCostGbp = Number((baseShippingCost + fuelSurcharge + clearanceFee).toFixed(2));
      
      const now = new Date();
      const daysToAdd = parseInt(q.deliveryDays.split('-')[0]) || 3;
      const estDate = new Date(now.setDate(now.getDate() + daysToAdd)).toLocaleDateString('en-GB', {
        weekday: 'short',
        day: 'numeric',
        month: 'short',
        year: 'numeric'
      });

      return {
        provider: q.provider,
        carrier: q.carrier,
        serviceName: q.serviceName,
        serviceCode: q.serviceCode,
        deliveryDays: q.deliveryDays,
        estimatedDeliveryDate: estDate,
        currency: 'GBP',
        baseShippingCostGbp: baseShippingCost,
        fuelSurchargeGbp: fuelSurcharge,
        customsClearanceFeeGbp: clearanceFee,
        totalShippingCostGbp,
        totalCostAed: Number((totalShippingCostGbp * gbpToAed).toFixed(2)),
        totalCostUsd: Number((totalShippingCostGbp * gbpToUsd).toFixed(2)),
        estimatedUaeCustomsDutyAed: estimatedDutyAed,
        estimatedUaeVatAed: estimatedVatAed,
        isMockData: true,
        notes: q.notes
      };
    });
  }

  /**
   * Execute or simulate ShipEngine Rate Query
   */
  public static async queryShipEngine(manifest: ToyShipmentManifest, apiKey?: string): Promise<CarrierRateQuote[]> {
    const key = apiKey || process.env.SHIPENGINE_API_KEY;
    if (!key) {
      return this.calculateBenchmarkRates(manifest, 'ShipEngine');
    }

    try {
      // Live API Call to ShipEngine /v1/rates
      const payload = {
        rate_options: {
          carrier_ids: [] // all connected
        },
        shipment: {
          validate_address: 'no_validation',
          ship_to: {
            name: manifest.recipient.contactName,
            company_name: manifest.recipient.company,
            phone: manifest.recipient.phone,
            address_line1: manifest.recipient.addressLine1,
            city_locality: manifest.recipient.city,
            postal_code: manifest.recipient.postalCode,
            country_code: manifest.recipient.country
          },
          ship_from: {
            name: manifest.sender.contactName,
            company_name: manifest.sender.company,
            phone: manifest.sender.phone,
            address_line1: manifest.sender.addressLine1,
            city_locality: manifest.sender.city,
            postal_code: manifest.sender.postalCode,
            country_code: manifest.sender.country
          },
          packages: manifest.packages.map(p => ({
            weight: { value: p.weightKg, unit: 'kilogram' },
            dimensions: {
              unit: 'centimeter',
              length: p.dimensionsCm.length,
              width: p.dimensionsCm.width,
              height: p.dimensionsCm.height
            }
          })),
          customs: {
            contents: 'merchandise',
            non_delivery: 'return_to_sender',
            customs_items: manifest.items.map(item => ({
              description: item.description,
              quantity: item.quantity,
              value: { amount: item.unitValue, currency: item.currency },
              harmonized_tariff_code: item.hsCode,
              country_of_origin: item.originCountry
            }))
          }
        }
      };

      const res = await fetch('https://api.shipengine.com/v1/rates', {
        method: 'POST',
        headers: {
          'API-Key': key,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        console.warn(`[ShipEngine Live] API returned ${res.status}, falling back to benchmark rates.`);
        return this.calculateBenchmarkRates(manifest, 'ShipEngine');
      }

      const data = await res.json() as any;
      const rateList = data.rate_response?.rates || [];
      if (rateList.length === 0) {
        return this.calculateBenchmarkRates(manifest, 'ShipEngine');
      }

      return rateList.map((r: any) => ({
        provider: 'ShipEngine',
        carrier: r.carrier_friendly_name || r.carrier_code,
        serviceName: r.service_type,
        serviceCode: r.service_code,
        deliveryDays: r.delivery_days ? `${r.delivery_days} Business Days` : '3-5 Days',
        estimatedDeliveryDate: r.estimated_delivery_date || 'Calculated at booking',
        currency: r.shipping_amount?.currency || 'GBP',
        baseShippingCostGbp: Number(r.shipping_amount?.amount || 0),
        fuelSurchargeGbp: Number(r.other_amount?.amount || 0),
        customsClearanceFeeGbp: 15.0,
        totalShippingCostGbp: Number((Number(r.shipping_amount?.amount || 0) + Number(r.other_amount?.amount || 0) + 15).toFixed(2)),
        totalCostAed: Number(((Number(r.shipping_amount?.amount || 0) + 15) * 4.75).toFixed(2)),
        totalCostUsd: Number(((Number(r.shipping_amount?.amount || 0) + 15) * 1.30).toFixed(2)),
        estimatedUaeCustomsDutyAed: Number((manifest.totalDeclaredValueAed * 0.05).toFixed(2)),
        estimatedUaeVatAed: Number((manifest.totalDeclaredValueAed * 1.05 * 0.05).toFixed(2)),
        isMockData: false,
        notes: 'Live rate retrieved from ShipEngine API.'
      }));
    } catch (err) {
      console.error('[ShipEngine API Error]', err);
      return this.calculateBenchmarkRates(manifest, 'ShipEngine');
    }
  }

  /**
   * Execute or simulate Shippo Rate Query
   */
  public static async queryShippo(manifest: ToyShipmentManifest, apiToken?: string): Promise<CarrierRateQuote[]> {
    const token = apiToken || process.env.SHIPPO_API_TOKEN;
    if (!token) {
      return this.calculateBenchmarkRates(manifest, 'Shippo');
    }

    try {
      const payload = {
        address_from: {
          name: manifest.sender.contactName,
          company: manifest.sender.company,
          street1: manifest.sender.addressLine1,
          city: manifest.sender.city,
          zip: manifest.sender.postalCode,
          country: manifest.sender.country,
          phone: manifest.sender.phone,
          email: manifest.sender.email
        },
        address_to: {
          name: manifest.recipient.contactName,
          company: manifest.recipient.company,
          street1: manifest.recipient.addressLine1,
          city: manifest.recipient.city,
          zip: manifest.recipient.postalCode,
          country: manifest.recipient.country,
          phone: manifest.recipient.phone,
          email: manifest.recipient.email
        },
        parcels: manifest.packages.map(p => ({
          length: p.dimensionsCm.length.toString(),
          width: p.dimensionsCm.width.toString(),
          height: p.dimensionsCm.height.toString(),
          distance_unit: 'cm',
          weight: p.weightKg.toString(),
          mass_unit: 'kg'
        })),
        async: false
      };

      const res = await fetch('https://api.goshippo.com/shipments/', {
        method: 'POST',
        headers: {
          'Authorization': `ShippoToken ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        return this.calculateBenchmarkRates(manifest, 'Shippo');
      }

      const data = await res.json() as any;
      const rates = data.rates || [];
      if (rates.length === 0) {
        return this.calculateBenchmarkRates(manifest, 'Shippo');
      }

      return rates.map((r: any) => ({
        provider: 'Shippo',
        carrier: r.provider,
        serviceName: r.servicelevel?.name || 'International Express',
        serviceCode: r.servicelevel?.token || 'intl_express',
        deliveryDays: r.estimated_days ? `${r.estimated_days} Days` : '2-4 Days',
        estimatedDeliveryDate: 'Calculated at booking',
        currency: r.currency || 'GBP',
        baseShippingCostGbp: Number(r.amount),
        fuelSurchargeGbp: 0,
        customsClearanceFeeGbp: 15.0,
        totalShippingCostGbp: Number(r.amount) + 15,
        totalCostAed: Number(((Number(r.amount) + 15) * 4.75).toFixed(2)),
        totalCostUsd: Number(((Number(r.amount) + 15) * 1.30).toFixed(2)),
        estimatedUaeCustomsDutyAed: Number((manifest.totalDeclaredValueAed * 0.05).toFixed(2)),
        estimatedUaeVatAed: Number((manifest.totalDeclaredValueAed * 1.05 * 0.05).toFixed(2)),
        isMockData: false,
        notes: 'Live rate retrieved from Shippo API.'
      }));
    } catch {
      return this.calculateBenchmarkRates(manifest, 'Shippo');
    }
  }

  /**
   * Execute or simulate EasyPost Rate Query
   */
  public static async queryEasyPost(manifest: ToyShipmentManifest, apiKey?: string): Promise<CarrierRateQuote[]> {
    const key = apiKey || process.env.EASYPOST_API_KEY;
    if (!key) {
      return this.calculateBenchmarkRates(manifest, 'EasyPost');
    }

    try {
      const auth = Buffer.from(`${key}:`).toString('base64');
      const payload = {
        shipment: {
          to_address: {
            name: manifest.recipient.contactName,
            company: manifest.recipient.company,
            street1: manifest.recipient.addressLine1,
            city: manifest.recipient.city,
            country: manifest.recipient.country,
            zip: manifest.recipient.postalCode,
            phone: manifest.recipient.phone
          },
          from_address: {
            name: manifest.sender.contactName,
            company: manifest.sender.company,
            street1: manifest.sender.addressLine1,
            city: manifest.sender.city,
            country: manifest.sender.country,
            zip: manifest.sender.postalCode,
            phone: manifest.sender.phone
          },
          parcel: {
            length: manifest.packages[0]?.dimensionsCm.length || 60,
            width: manifest.packages[0]?.dimensionsCm.width || 40,
            height: manifest.packages[0]?.dimensionsCm.height || 40,
            weight: manifest.chargeableWeightKg * 35.274 // kg to oz
          }
        }
      };

      const res = await fetch('https://api.easypost.com/v2/shipments', {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${auth}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        return this.calculateBenchmarkRates(manifest, 'EasyPost');
      }

      const data = await res.json() as any;
      const rates = data.rates || [];
      if (rates.length === 0) {
        return this.calculateBenchmarkRates(manifest, 'EasyPost');
      }

      return rates.map((r: any) => ({
        provider: 'EasyPost',
        carrier: r.carrier,
        serviceName: r.service,
        serviceCode: r.id,
        deliveryDays: r.delivery_days ? `${r.delivery_days} Days` : '3-5 Days',
        estimatedDeliveryDate: r.delivery_date || 'Calculated at booking',
        currency: r.currency || 'GBP',
        baseShippingCostGbp: Number(r.rate),
        fuelSurchargeGbp: 0,
        customsClearanceFeeGbp: 15.0,
        totalShippingCostGbp: Number(r.rate) + 15,
        totalCostAed: Number(((Number(r.rate) + 15) * 4.75).toFixed(2)),
        totalCostUsd: Number(((Number(r.rate) + 15) * 1.30).toFixed(2)),
        estimatedUaeCustomsDutyAed: Number((manifest.totalDeclaredValueAed * 0.05).toFixed(2)),
        estimatedUaeVatAed: Number((manifest.totalDeclaredValueAed * 1.05 * 0.05).toFixed(2)),
        isMockData: false,
        notes: 'Live rate retrieved from EasyPost API.'
      }));
    } catch {
      return this.calculateBenchmarkRates(manifest, 'EasyPost');
    }
  }

  /**
   * Execute or simulate Sendcloud Rate Query
   */
  public static async querySendcloud(manifest: ToyShipmentManifest, pubKey?: string, secKey?: string): Promise<CarrierRateQuote[]> {
    const pub = pubKey || process.env.SENDCLOUD_PUBLIC_KEY;
    const sec = secKey || process.env.SENDCLOUD_SECRET_KEY;
    
    if (!pub || !sec) {
      return this.calculateBenchmarkRates(manifest, 'Sendcloud');
    }

    try {
      const auth = Buffer.from(`${pub}:${sec}`).toString('base64');
      const res = await fetch(`https://panel.sendcloud.sc/api/v2/shipping-methods?from_country=GB&to_country=AE&weight=${manifest.chargeableWeightKg}&weight_unit=kilogram`, {
        method: 'GET',
        headers: {
          'Authorization': `Basic ${auth}`,
          'Accept': 'application/json'
        }
      });

      if (!res.ok) {
        return this.calculateBenchmarkRates(manifest, 'Sendcloud');
      }

      const data = await res.json() as any;
      const methods = data.shipping_methods || [];
      if (methods.length === 0) {
        return this.calculateBenchmarkRates(manifest, 'Sendcloud');
      }

      return methods.map((m: any) => ({
        provider: 'Sendcloud',
        carrier: m.carrier?.name || 'Sendcloud Partner',
        serviceName: m.name,
        serviceCode: m.id.toString(),
        deliveryDays: '2-4 Business Days',
        estimatedDeliveryDate: 'Calculated at booking',
        currency: 'GBP',
        baseShippingCostGbp: Number(m.price || 0),
        fuelSurchargeGbp: 0,
        customsClearanceFeeGbp: 15.0,
        totalShippingCostGbp: Number(m.price || 0) + 15,
        totalCostAed: Number(((Number(m.price || 0) + 15) * 4.75).toFixed(2)),
        totalCostUsd: Number(((Number(m.price || 0) + 15) * 1.30).toFixed(2)),
        estimatedUaeCustomsDutyAed: Number((manifest.totalDeclaredValueAed * 0.05).toFixed(2)),
        estimatedUaeVatAed: Number((manifest.totalDeclaredValueAed * 1.05 * 0.05).toFixed(2)),
        isMockData: false,
        notes: 'Live rate retrieved from Sendcloud UK API.'
      }));
    } catch {
      return this.calculateBenchmarkRates(manifest, 'Sendcloud');
    }
  }

  /**
   * Compare all 4 providers side-by-side
   */
  public static async compareAllProviders(manifest: ToyShipmentManifest, keys?: {
    shipEngineApiKey?: string;
    shippoToken?: string;
    easyPostKey?: string;
    sendcloudPubKey?: string;
    sendcloudSecKey?: string;
  }): Promise<{
    manifest: ToyShipmentManifest;
    comparisonSummary: {
      cheapestOption: CarrierRateQuote;
      fastestOption: CarrierRateQuote;
      bestOverall: CarrierRateQuote;
      averageCostGbp: number;
    };
    quotes: CarrierRateQuote[];
  }> {
    const [shipEngineQuotes, shippoQuotes, easyPostQuotes, sendcloudQuotes] = await Promise.all([
      this.queryShipEngine(manifest, keys?.shipEngineApiKey),
      this.queryShippo(manifest, keys?.shippoToken),
      this.queryEasyPost(manifest, keys?.easyPostKey),
      this.querySendcloud(manifest, keys?.sendcloudPubKey, keys?.sendcloudSecKey)
    ]);

    const allQuotes = [...shipEngineQuotes, ...shippoQuotes, ...easyPostQuotes, ...sendcloudQuotes];
    allQuotes.sort((a, b) => a.totalShippingCostGbp - b.totalShippingCostGbp);

    const cheapest = allQuotes[0];
    const fastest = allQuotes.find(q => q.serviceName.includes('Priority') || q.serviceName.includes('12:00') || q.serviceName.includes('Express')) || allQuotes[0];
    const bestOverall = allQuotes.find(q => q.carrier === 'DHL Express' && q.serviceName.includes('Worldwide')) || allQuotes[0];
    const avgCost = Number((allQuotes.reduce((acc, q) => acc + q.totalShippingCostGbp, 0) / (allQuotes.length || 1)).toFixed(2));

    return {
      manifest,
      comparisonSummary: {
        cheapestOption: cheapest,
        fastestOption: fastest,
        bestOverall,
        averageCostGbp: avgCost
      },
      quotes: allQuotes
    };
  }
}
