import React, { useState } from 'react';
import { 
  CalendarCheck, 
  MapPin, 
  PhoneCall, 
  Key, 
  Send, 
  ShieldCheck, 
  PhoneOff, 
  Mic, 
  MicOff 
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

  // In-app chat simulation state
  const [chatMessages, setChatMessages] = useState<Array<{ sender: string; text: string; time: string; isOwner?: boolean }>>([
    { sender: 'Femi Adesanya (Prospect)', text: 'Good day Chief Falana. I booked an inspection for 11 AM Saturday.', time: '10:02 AM' },
    { sender: 'Chief Adebayo Falana (Owner)', text: 'Good day Femi! Yes, I have confirmed your slot. I will have the facility manager Mr. Sunday open the gate for you.', time: '10:05 AM', isOwner: true },
    { sender: 'Femi Adesanya (Prospect)', text: 'Perfect. Does the service charge cover 24/7 central generator diesel?', time: '10:07 AM' },
    { sender: 'Chief Adebayo Falana (Owner)', text: 'Yes, 100%. We run 24 hours light, treated water, and 2 armed security personnel.', time: '10:08 AM', isOwner: true }
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
    onBookInspection(bookingData);
    setShowBookingForm(false);
  };

  // Call simulator timer
  React.useEffect(() => {
    let interval: any = null;
    if (activeCall) {
      interval = setInterval(() => setCallDuration((prev) => prev + 1), 1000);
    } else {
      setCallDuration(0);
    }
    return () => clearInterval(interval);
  }, [activeCall]);

  const formatCallTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <CalendarCheck className="w-6 h-6 text-emerald-400" />
            <span>Inspection Scheduler & In-App Coordination</span>
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Direct owner-prospect physical inspection booking with secure verification pass codes.
          </p>
        </div>

        <button
          onClick={() => setShowBookingForm(!showBookingForm)}
          className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-900/30 transition self-start sm:self-auto"
        >
          {showBookingForm ? 'Close Form' : '+ Book New Inspection'}
        </button>
      </div>

      {/* Booking Form Modal / Banner */}
      {showBookingForm && (
        <div className="p-5 rounded-2xl bg-slate-900 border border-emerald-500/40 space-y-4 shadow-xl">
          <h2 className="text-sm font-bold text-white flex items-center gap-2">
            <CalendarCheck className="w-4 h-4 text-emerald-400" />
            <span>Schedule Physical Inspection Slot</span>
          </h2>

          <form onSubmit={handleCreateBooking} className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
            <div>
              <label className="block text-slate-300 font-semibold mb-1">Select Property</label>
              <select
                value={bookingData.propertyId}
                onChange={(e) => setBookingData({ ...bookingData, propertyId: e.target.value })}
                className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-200"
              >
                {properties.map((p) => (
                  <option key={p.id} value={p.id}>{p.title} ({p.neighborhood})</option>
                ))}
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
                className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold transition shadow-md"
              >
                Generate Verified Inspection Pass
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Main Two-Column Layout: Inspections List & In-App Coordination */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Scheduled Appointments (5 cols) */}
        <div className="lg:col-span-5 space-y-3">
          <h2 className="text-xs font-bold uppercase tracking-wider text-slate-400">
            Active Appointments ({inspections.length})
          </h2>

          <div className="space-y-3">
            {inspections.map((insp) => {
              const isSelected = selectedInspection?.id === insp.id;
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

        {/* Right Column: In-App Chat & Call Room Simulator (7 cols) */}
        <div className="lg:col-span-7 space-y-4">
          {selectedInspection ? (
            <div className="rounded-2xl bg-slate-900 border border-slate-800 flex flex-col h-[560px] overflow-hidden shadow-xl">
              {/* Chat Header */}
              <div className="p-4 border-b border-slate-800 bg-slate-950/80 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-emerald-600/20 text-emerald-400 flex items-center justify-center font-bold">
                    <ShieldCheck className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white flex items-center gap-2">
                      <span>{selectedInspection.ownerName} & {selectedInspection.prospectName}</span>
                    </h3>
                    <p className="text-[11px] text-emerald-400 flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                      <span>Encrypted In-App Chat Room • Pass #{selectedInspection.inspectionPassCode}</span>
                    </p>
                  </div>
                </div>

                {/* Call Action Button */}
                <div className="flex items-center gap-2">
                  {!activeCall ? (
                    <button
                      onClick={() => setActiveCall(true)}
                      className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold transition flex items-center gap-1.5 shadow-md"
                    >
                      <PhoneCall className="w-3.5 h-3.5" />
                      <span>In-App Call</span>
                    </button>
                  ) : (
                    <button
                      onClick={() => setActiveCall(false)}
                      className="px-3 py-1.5 rounded-xl bg-red-600 hover:bg-red-500 text-white text-xs font-bold transition flex items-center gap-1.5 shadow-md animate-pulse"
                    >
                      <PhoneOff className="w-3.5 h-3.5" />
                      <span>End Call ({formatCallTime(callDuration)})</span>
                    </button>
                  )}
                </div>
              </div>

              {/* Call Active Floating Banner */}
              {activeCall && (
                <div className="p-3 bg-emerald-950/80 border-b border-emerald-800 flex items-center justify-between text-xs px-6">
                  <div className="flex items-center gap-2 text-emerald-300 font-semibold">
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
                    <span>Live Masked VoIP Call in Progress ({formatCallTime(callDuration)})</span>
                  </div>
                  <button
                    onClick={() => setIsMuted(!isMuted)}
                    className="p-1.5 rounded-lg bg-slate-900 text-slate-300 hover:text-white"
                  >
                    {isMuted ? <MicOff className="w-4 h-4 text-red-400" /> : <Mic className="w-4 h-4 text-emerald-400" />}
                  </button>
                </div>
              )}

              {/* Chat Message Stream */}
              <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-slate-950/40">
                {chatMessages.map((msg, index) => (
                  <div
                    key={index}
                    className={`flex flex-col ${msg.isOwner ? 'items-start' : 'items-end'}`}
                  >
                    <div
                      className={`max-w-[80%] p-3 rounded-2xl text-xs space-y-1 ${
                        msg.isOwner
                          ? 'bg-slate-800 text-slate-200 rounded-tl-none border border-slate-700'
                          : 'bg-emerald-600 text-white rounded-tr-none shadow-md'
                      }`}
                    >
                      <p className="text-[10px] font-semibold opacity-75">{msg.sender}</p>
                      <p className="leading-relaxed">{msg.text}</p>
                      <span className="text-[9px] opacity-60 block text-right">{msg.time}</span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Chat Input */}
              <form onSubmit={handleSendMessage} className="p-3 bg-slate-950 border-t border-slate-800 flex items-center gap-2">
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Type a message or legal inquiry regarding inspection..."
                  className="flex-1 px-4 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-emerald-500"
                />
                <button
                  type="submit"
                  className="p-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white transition shadow-md"
                >
                  <Send className="w-4 h-4" />
                </button>
              </form>
            </div>
          ) : (
            <div className="p-12 text-center text-slate-500 text-xs rounded-2xl bg-slate-900 border border-slate-800">
              Select an inspection to view communications and verified pass codes.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
