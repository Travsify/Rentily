import React, { useState } from 'react';
import { X, Building2, ShieldCheck, Plus } from 'lucide-react';
import type { TitleDocumentType } from '../types';

interface PropertyModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (propertyData: any) => void;
}

export const PropertyModal: React.FC<PropertyModalProps> = ({ isOpen, onClose, onSave }) => {
  if (!isOpen) return null;

  const [step, setStep] = useState<1 | 2>(1);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    purpose: 'rent' as 'rent' | 'sale',
    propertyType: 'flat_apartment',
    basePrice: '',
    cautionFee: '',
    serviceCharge: '',
    address: '',
    state: 'Lagos',
    lga: 'Eti-Osa',
    neighborhood: 'Lekki Phase 1',
    bedrooms: '3',
    bathrooms: '3',
    furnishing: 'unfurnished',
    ownerName: '',
    ownerPhone: '',
    // KYP fields
    titleDocumentType: 'governors_consent' as TitleDocumentType,
    titleDocumentNumber: '',
    ownerIdType: 'NIN',
    ownerIdNumber: '',
    discoProvider: 'EKEDC',
    discoMeterNumber: ''
  });

  const basePriceNum = Number(formData.basePrice || 0);
  const feePct = formData.purpose === 'rent' ? 0.10 : 0.05;
  const rentillyFee = Math.round(basePriceNum * feePct);
  const cautionNum = Number(formData.cautionFee || 0);
  const serviceNum = Number(formData.serviceCharge || 0);
  const totalPayment = basePriceNum + cautionNum + serviceNum + rentillyFee;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.title || !formData.basePrice || !formData.address) {
      alert('Please fill all required property fields');
      return;
    }
    onSave(formData);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm overflow-y-auto">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/60">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-600/20 text-emerald-400 flex items-center justify-center">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold text-white">List Direct Owner Property</h2>
              <p className="text-xs text-slate-400">Zero Agent Listing with Mandatory KYP Verification</p>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-4 text-xs">
          {/* Step Indicator */}
          <div className="flex items-center justify-center gap-3 pb-2 border-b border-slate-800">
            <button
              type="button"
              onClick={() => setStep(1)}
              className={`px-3.5 py-1.5 rounded-lg font-semibold flex items-center gap-2 ${
                step === 1 ? 'bg-emerald-600 text-white' : 'text-slate-400 bg-slate-800'
              }`}
            >
              <span>1. Property & Pricing</span>
            </button>
            <button
              type="button"
              onClick={() => setStep(2)}
              className={`px-3.5 py-1.5 rounded-lg font-semibold flex items-center gap-2 ${
                step === 2 ? 'bg-emerald-600 text-white' : 'text-slate-400 bg-slate-800'
              }`}
            >
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>2. KYP Title Deeds & ID</span>
            </button>
          </div>

          {step === 1 && (
            <div className="space-y-4">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Listing Purpose</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, purpose: 'rent' })}
                    className={`py-2 rounded-xl font-bold border transition ${
                      formData.purpose === 'rent'
                        ? 'bg-emerald-600/20 text-emerald-300 border-emerald-500/40'
                        : 'bg-slate-950 text-slate-400 border-slate-800'
                    }`}
                  >
                    For Rent (10% Legal Fee)
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, purpose: 'sale' })}
                    className={`py-2 rounded-xl font-bold border transition ${
                      formData.purpose === 'sale'
                        ? 'bg-emerald-600/20 text-emerald-300 border-emerald-500/40'
                        : 'bg-slate-950 text-slate-400 border-slate-800'
                    }`}
                  >
                    For Outright Sale (5% Legal/Search)
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Property Title *</label>
                <input
                  type="text"
                  required
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="e.g. Modern 3-Bedroom Serviced Apartment with Pool"
                  className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">
                    {formData.purpose === 'rent' ? 'Annual Rent (₦) *' : 'Sale Price (₦) *'}
                  </label>
                  <input
                    type="number"
                    required
                    value={formData.basePrice}
                    onChange={(e) => setFormData({ ...formData, basePrice: e.target.value })}
                    placeholder="e.g. 5000000"
                    className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 font-mono"
                  />
                </div>

                {formData.purpose === 'rent' ? (
                  <div>
                    <label className="block text-slate-300 font-semibold mb-1">Caution Deposit (₦)</label>
                    <input
                      type="number"
                      value={formData.cautionFee}
                      onChange={(e) => setFormData({ ...formData, cautionFee: e.target.value })}
                      placeholder="e.g. 500000"
                      className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500 font-mono"
                    />
                  </div>
                ) : (
                  <div>
                    <label className="block text-slate-300 font-semibold mb-1">Bedrooms</label>
                    <input
                      type="number"
                      value={formData.bedrooms}
                      onChange={(e) => setFormData({ ...formData, bedrooms: e.target.value })}
                      className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                )}
              </div>

              {formData.purpose === 'rent' && (
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-slate-300 font-semibold mb-1">Service Charge (₦)</label>
                    <input
                      type="number"
                      value={formData.serviceCharge}
                      onChange={(e) => setFormData({ ...formData, serviceCharge: e.target.value })}
                      placeholder="e.g. 600000"
                      className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 font-mono"
                    />
                  </div>
                  <div>
                    <label className="block text-slate-300 font-semibold mb-1">Bedrooms</label>
                    <input
                      type="number"
                      value={formData.bedrooms}
                      onChange={(e) => setFormData({ ...formData, bedrooms: e.target.value })}
                      className="w-full px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                    />
                  </div>
                </div>
              )}

              {/* Live Fee Calculator Breakdown */}
              {basePriceNum > 0 && (
                <div className="p-3.5 rounded-xl bg-emerald-950/40 border border-emerald-800/60 space-y-1">
                  <div className="flex justify-between font-bold text-emerald-300">
                    <span>Rentilly Legal & Verification Fee ({formData.purpose === 'rent' ? '10%' : '5%'}):</span>
                    <span>₦{rentillyFee.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between text-slate-300 text-[11px]">
                    <span>Total Initial Tenant/Buyer Payment:</span>
                    <span className="font-bold text-white">₦{totalPayment.toLocaleString()}</span>
                  </div>
                  <p className="text-[10px] text-emerald-400 mt-1">
                    ✓ Full Nigerian Tenancy Agreement + Move-in Guarantee included (Zero Agent fee).
                  </p>
                </div>
              )}

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">State</label>
                  <select
                    value={formData.state}
                    onChange={(e) => setFormData({ ...formData, state: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                  >
                    <option value="Lagos">Lagos</option>
                    <option value="Abuja FCT">Abuja FCT</option>
                    <option value="Rivers">Rivers</option>
                    <option value="Oyo">Oyo</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Neighborhood</label>
                  <input
                    type="text"
                    value={formData.neighborhood}
                    onChange={(e) => setFormData({ ...formData, neighborhood: e.target.value })}
                    placeholder="e.g. Lekki Phase 1"
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                  />
                </div>

                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Address *</label>
                  <input
                    type="text"
                    required
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    placeholder="Plot 10, Admiralty Way"
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Description</label>
                <textarea
                  rows={2}
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Details regarding 24/7 power, treated water, fitted kitchen..."
                  className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                />
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div className="p-3.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-300 space-y-1">
                <span className="font-bold block">Mandatory KYP (Know Your Property) Guarantee</span>
                <p className="text-[11px] text-slate-300">
                  Every property must have verifiable land title documents and a matching electricity meter before publication.
                </p>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Title Document Type</label>
                  <select
                    value={formData.titleDocumentType}
                    onChange={(e) => setFormData({ ...formData, titleDocumentType: e.target.value as TitleDocumentType })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                  >
                    <option value="c_of_o">Certificate of Occupancy (C of O)</option>
                    <option value="governors_consent">Governor's Consent</option>
                    <option value="deed_of_assignment">Registered Deed of Assignment</option>
                    <option value="gazette_excision">Gazette / Excision</option>
                    <option value="letter_of_administration">Letter of Administration</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Deed / Reg File Number</label>
                  <input
                    type="text"
                    value={formData.titleDocumentNumber}
                    onChange={(e) => setFormData({ ...formData, titleDocumentNumber: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Owner Government ID</label>
                  <select
                    value={formData.ownerIdType}
                    onChange={(e) => setFormData({ ...formData, ownerIdType: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                  >
                    <option value="NIN">National Identity Number (NIN)</option>
                    <option value="International Passport">International Passport</option>
                    <option value="Drivers License">Driver's License</option>
                    <option value="Voters Card">Voter's Card</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-300 font-semibold mb-1">ID Number</label>
                  <input
                    type="text"
                    value={formData.ownerIdNumber}
                    onChange={(e) => setFormData({ ...formData, ownerIdNumber: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Disco Electricity Provider</label>
                  <select
                    value={formData.discoProvider}
                    onChange={(e) => setFormData({ ...formData, discoProvider: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
                  >
                    <option value="EKEDC">Eko Disco (EKEDC - Lagos Island/Lekki)</option>
                    <option value="IKEDC">Ikeja Disco (IKEDC - Lagos Mainland)</option>
                    <option value="AEDC">Abuja Disco (AEDC - Abuja FCT)</option>
                    <option value="PHED">Port Harcourt Disco (PHED)</option>
                    <option value="IBEDC">Ibadan Disco (IBEDC)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-300 font-semibold mb-1">Prepaid Meter Number</label>
                  <input
                    type="text"
                    value={formData.discoMeterNumber}
                    onChange={(e) => setFormData({ ...formData, discoMeterNumber: e.target.value })}
                    className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200 font-mono"
                  />
                </div>
              </div>
            </div>
          )}

          {/* Footer Buttons */}
          <div className="pt-4 border-t border-slate-800 flex items-center justify-between">
            {step === 2 ? (
              <button
                type="button"
                onClick={() => setStep(1)}
                className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:text-white"
              >
                Back
              </button>
            ) : (
              <div></div>
            )}

            {step === 1 ? (
              <button
                type="button"
                onClick={() => setStep(2)}
                className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold"
              >
                Proceed to KYP Upload
              </button>
            ) : (
              <button
                type="submit"
                className="px-6 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold shadow-lg flex items-center gap-1.5"
              >
                <Plus className="w-4 h-4" />
                <span>Submit Direct Listing & Queue for KYP</span>
              </button>
            )}
          </div>
        </form>
      </div>
    </div>
  );
};
