import React, { useState } from 'react';
import { 
  CalendarCheck, 
  MapPin, 
  PhoneCall, 
  Key, 
  Send, 
  PhoneOff, 
  Mic, 
  MicOff,
  Plus
} from 'lucide-react';
import type { Inspection, Property } from '../types';

interface InspectionsTabProps {
  inspections: Inspection[];
  properties: Property[];
  onBookInspection: (data: any) => void;
  onUpdateStatus?: (id: string, status: Inspection['status'], notes?: string) => void;
}

export const InspectionsTab: React.FC<InspectionsTabProps> = ({
  inspections,
  properties,
  onBookInspection
}) => {
  const [selectedInspection, setSelectedInspection] = useState<Inspection | null>(inspections[0] || null);
  const [showBookingForm, setShowBookingForm] = useState(false);
  const [activeCall, setActiveCall] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [callDuration, setCallDuration] = useState(0);

  // In-app chat state
  const [chatMessages, setChatMessages] = useState<Array<{ sender: string; text: string; time: string; isOwner?: boolean }>>([
    { sender: 'Prospective Tenant', text: 'Hello! I scheduled a physical inspection pass.', time: '10:02 AM' },
    { sender: 'Property Owner', text: 'Hello! Your pass has been authorized. The facility manager will be expecting you.', time: '10:05 AM', isOwner: true }
  ]);
  const [newMessage, setNewMessage] = useState('');

  // New Inspection Booking Form state
  const [bookingData, setBookingData] = useState({
    propertyId: properties[0]?.id || '',
    scheduledDate: new Date(Date.now() + 86400000 * 2).toISOString().split('T')[0],
    scheduledTimeSlot: '11:00 AM - 12:00 PM',
    prospectName: 'Dr. Somtochukwu Eze',
    prospectPhone: '+234 818 765 4321',
    prospectNotes: 'Looking forward to viewing the title documents and physical structure.'
  });

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim()) return;
    setChatMessages([
      ...chatMessages,
      { sender: 'You (Admin/Legal Desk)', text: newMessage, time: 'Just now' }
    ]);
    setNewMessage('');
  };

  const handleCreateBooking = (e: React.FormEvent) => {
    e.preventDefault();
    if (!bookingData.propertyId && properties.length > 0) {
      bookingData.propertyId = properties[0].id;
    }
    onBookInspection(bookingData);
    setShowBookingForm(false);
  };

  const handleToggleCall = () => {
    if (!activeCall) {
      setActiveCall(true);
      setCallDuration(0);
    } else {
      setActiveCall(false);
    }
  };

  const currentInsp = selectedInspection || inspections[0] || null;

  return (
    <div className="space-y-6">
      {/* Tab Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <CalendarCheck className="w-6 h-6 text-emerald-400" />
            <span>Inspection Scheduler & Direct Coordination</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Book physical inspections, issue 6-digit gate pass codes, and manage direct in-app chat & calls without middleman agents.
          </p>
        </div>

        <button
          onClick={() => setShowBookingForm(!showBookingForm)}
          className="flex items-center gap-2 px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-900/30 transition self-start sm:self-auto"
        >
          <Plus className="w-4 h-4" />
          <span>{showBookingForm ? 'Cancel Form' : 'Schedule Inspection'}</span>
        </button>
      </div>

      {/* Booking Form Modal/Drawer */}
      {showBookingForm && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-emerald-500/40 shadow-xl space-y-4">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <Key className="w-4 h-4 text-emerald-400" />
            <span>Book New Physical Inspection Slot</span>
          </h2>

          <form onSubmit={handleCreateBooking} className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
            <div>
              <label className="block text-slate-300 font-semibold mb-1">Select Property</label>
              <select
                required
                value={bookingData.propertyId}
                onChange={(e) => setBookingData({ ...bookingData, propertyId: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
              >
                {properties.length === 0 ? (
                  <option value="">No properties available (add one first)</option>
                ) : (
                  properties.map((p) => (
                    <option key={p.id} value={p.id}>{p.title} ({p.neighborhood})</option>
                  ))
                )}
              </select>
            </div>

            <div>
              <label className="block text-slate-300 font-semibold mb-1">Inspection Date</label>
              <input
                type="date"
                required
                value={bookingData.scheduledDate}
                onChange={(e) => setBookingData({ ...bookingData, scheduledDate: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-semibold mb-1">Time Window</label>
              <select
                value={bookingData.scheduledTimeSlot}
                onChange={(e) => setBookingData({ ...bookingData, scheduledTimeSlot: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
              >
                <option value="09:00 AM - 10:00 AM">09:00 AM - 10:00 AM</option>
                <option value="11:00 AM - 12:00 PM">11:00 AM - 12:00 PM</option>
                <option value="02:00 PM - 03:00 PM">02:00 PM - 03:00 PM</option>
                <option value="04:00 PM - 05:00 PM">04:00 PM - 05:00 PM</option>
              </select>
            </div>

            <div>
              <label className="block text-slate-300 font-semibold mb-1">Prospect Full Name</label>
              <input
                type="text"
                required
                value={bookingData.prospectName}
                onChange={(e) => setBookingData({ ...bookingData, prospectName: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-semibold mb-1">Prospect Phone Number</label>
              <input
                type="text"
                required
                value={bookingData.prospectPhone}
                onChange={(e) => setBookingData({ ...bookingData, prospectPhone: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
              />
            </div>

            <div className="flex items-end">
              <button
                type="submit"
                disabled={properties.length === 0}
                className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold transition shadow-md"
              >
                Generate Verified Inspection Pass
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Main Two-Column Layout or Empty State */}
      {inspections.length === 0 ? (
        <div className="p-12 text-center rounded-3xl bg-slate-900/40 border border-slate-800/80 space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-slate-800/80 flex items-center justify-center mx-auto text-emerald-400">
            <CalendarCheck className="w-7 h-7" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="text-base font-bold text-white">No Scheduled Inspections</h3>
            <p className="text-xs text-slate-400">
              When prospective renters or buyers book property inspections from the mobile app or web portal, their appointments and 6-digit gate passes will be managed here.
            </p>
          </div>
          <button
            onClick={() => setShowBookingForm(true)}
            className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-lg shadow-emerald-950/50 transition inline-flex items-center gap-1.5"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Schedule First Inspection</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Left Column: Scheduled Appointments (5 cols) */}
          <div className="lg:col-span-5 space-y-3">
            <h2 className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Active Appointments ({inspections.length})
            </h2>

            <div className="space-y-3">
              {inspections.map((insp) => {
                const isSelected = currentInsp?.id === insp.id;
                const isConfirmed = insp.status === 'confirmed';

                return (
                  <div
                    key={insp.id}
                    onClick={() => setSelectedInspection(insp)}
                    className={`p-4 rounded-2xl cursor-pointer border transition ${
                      isSelected
                        ? 'bg-slate-850 border-emerald-500 ring-1 ring-emerald-500/30'
                        : 'bg-slate-900 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <span className="text-[10px] font-mono uppercase text-slate-500">
                          {insp.id} • {insp.scheduledDate}
                        </span>
                        <h3 className="font-bold text-sm text-white mt-0.5">{insp.propertyTitle}</h3>
                        <p className="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
                          <MapPin className="w-3.5 h-3.5 text-emerald-400" />
                          <span>{insp.propertyAddress}</span>
                        </p>
                      </div>

                      <span
                        className={`text-[10px] px-2.5 py-1 rounded-full font-bold uppercase ${
                          isConfirmed
                            ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                            : 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                        }`}
                      >
                        {insp.status.replace(/_/g, ' ')}
                      </span>
                    </div>

                    <div className="mt-3 pt-2.5 border-t border-slate-800 flex items-center justify-between text-xs">
                      <div className="flex items-center gap-2">
                        <span className="text-slate-400">Time:</span>
                        <span className="text-emerald-400 font-semibold">{insp.scheduledTimeSlot}</span>
                      </div>

                      {/* Inspection Pass Code */}
                      <div className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-md bg-slate-950 border border-slate-700 font-mono text-[11px] text-amber-300">
                        <Key className="w-3 h-3 text-amber-400" />
                        <span>PASS: {insp.inspectionPassCode}</span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Right Column: In-App Coordination Desk (7 cols) */}
          {currentInsp && (
            <div className="lg:col-span-7 space-y-4">
              {/* Selected Inspection Card */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-3">
                <div className="flex items-start justify-between">
                  <div>
                    <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-400 px-2 py-0.5 rounded bg-emerald-500/10 border border-emerald-500/20">
                      Physical Inspection Gate Pass
                    </span>
                    <h2 className="text-base font-bold text-white mt-1.5">{currentInsp.propertyTitle}</h2>
                    <p className="text-xs text-slate-400">{currentInsp.propertyAddress}</p>
                  </div>

                  {/* 6-Digit Gate Code Box */}
                  <div className="text-center p-2.5 rounded-xl bg-slate-950 border border-amber-500/30">
                    <span className="text-[10px] text-slate-500 uppercase font-semibold block">Gate Pass Code</span>
                    <span className="text-lg font-mono font-bold text-amber-400 tracking-wider">
                      {currentInsp.inspectionPassCode}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3 pt-2 border-t border-slate-800 text-xs">
                  <div className="p-2.5 rounded-xl bg-slate-950/60 border border-slate-800">
                    <span className="text-[10px] text-slate-500 uppercase font-semibold block">Prospect / Renter</span>
                    <span className="text-slate-200 font-medium">{currentInsp.prospectName}</span>
                    <span className="text-[10px] text-slate-400 block">{currentInsp.prospectPhone}</span>
                  </div>

                  <div className="p-2.5 rounded-xl bg-slate-950/60 border border-slate-800">
                    <span className="text-[10px] text-slate-500 uppercase font-semibold block">Direct Landlord</span>
                    <span className="text-slate-200 font-medium">{currentInsp.ownerName}</span>
                    <span className="text-[10px] text-slate-400 block">{currentInsp.ownerPhone}</span>
                  </div>
                </div>
              </div>

              {/* Direct In-App Chat Room */}
              <div className="rounded-2xl bg-slate-900 border border-slate-800 flex flex-col h-[380px] overflow-hidden shadow-sm">
                {/* Chat Room Top Bar with Voice Call Trigger */}
                <div className="p-3.5 bg-slate-850 border-b border-slate-800 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
                    <div>
                      <h3 className="text-xs font-bold text-white">Direct Landlord & Prospect In-App Channel</h3>
                      <p className="text-[10px] text-slate-400">Zero Middlemen • End-to-End Escrow Protected</p>
                    </div>
                  </div>

                  <button
                    onClick={handleToggleCall}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition ${
                      activeCall
                        ? 'bg-red-500 hover:bg-red-600 text-white animate-pulse'
                        : 'bg-emerald-600 hover:bg-emerald-500 text-white'
                    }`}
                  >
                    {activeCall ? (
                      <>
                        <PhoneOff className="w-3.5 h-3.5" />
                        <span>End Voice Call ({callDuration}s)</span>
                      </>
                    ) : (
                      <>
                        <PhoneCall className="w-3.5 h-3.5" />
                        <span>In-App Audio Call</span>
                      </>
                    )}
                  </button>
                </div>

                {/* Active VoIP Calling Overlay */}
                {activeCall && (
                  <div className="bg-emerald-950/80 border-b border-emerald-500/40 p-3 flex items-center justify-between text-xs text-emerald-200">
                    <div className="flex items-center gap-2">
                      <div className="p-1.5 rounded-full bg-emerald-500/20">
                        <PhoneCall className="w-4 h-4 text-emerald-400 animate-bounce" />
                      </div>
                      <div>
                        <span className="font-bold">In-App Voice Call Connected:</span>
                        <span className="text-[11px] text-emerald-300 ml-1.5">{currentInsp.ownerName} & {currentInsp.prospectName}</span>
                      </div>
                    </div>

                    <button
                      onClick={() => setIsMuted(!isMuted)}
                      className="p-1.5 rounded-lg bg-emerald-900/60 hover:bg-emerald-800 text-emerald-300"
                    >
                      {isMuted ? <MicOff className="w-3.5 h-3.5" /> : <Mic className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                )}

                {/* Messages Feed */}
                <div className="flex-1 p-4 overflow-y-auto space-y-3 text-xs bg-slate-950/40">
                  {chatMessages.map((msg, idx) => (
                    <div
                      key={idx}
                      className={`p-3 rounded-2xl max-w-[85%] space-y-1 ${
                        msg.isOwner
                          ? 'ml-auto bg-emerald-950/50 border border-emerald-500/30 text-emerald-100'
                          : 'mr-auto bg-slate-850 border border-slate-700/80 text-slate-200'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-4 text-[10px] text-slate-400">
                        <span className="font-semibold">{msg.sender}</span>
                        <span>{msg.time}</span>
                      </div>
                      <p className="text-xs leading-relaxed">{msg.text}</p>
                    </div>
                  ))}
                </div>

                {/* Input Send Bar */}
                <form onSubmit={handleSendMessage} className="p-3 bg-slate-900 border-t border-slate-800 flex gap-2">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="Type official message or inspection note..."
                    className="flex-1 px-3.5 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
                  />
                  <button
                    type="submit"
                    className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold flex items-center gap-1.5 transition"
                  >
                    <Send className="w-3.5 h-3.5" />
                    <span>Send</span>
                  </button>
                </form>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
