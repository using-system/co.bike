import { useState, useEffect } from 'react';
import { MapContainer, TileLayer, ZoomControl, Marker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { Control } from 'leaflet';

// Custom icon for the marker
const userIcon = new L.Icon({
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  shadowSize: [41, 41]
});

// Component to center the map on the user's position
function CenterMap({ position }) {
  const map = useMap();
  useEffect(() => {
    if (position) {
      map.setView(position, map.getZoom());
    }
  }, [position, map]);
  return null;
}

// Custom control to recenter the map
const RecenterControl = ({ position }) => {
  const map = useMap();
  const handleClick = () => {
    map.setView(position, map.getZoom());
  };

  useEffect(() => {
    const control = new Control({ position: 'bottomright' });
    control.onAdd = () => {
      const img = L.DomUtil.create('img', 'recenter-button');
      img.src = 'data:image/svg+xml;base64,' + btoa(`
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0-6h1v3h-2V4h1zm0 14h1v3h-2v-3h1zm7-7h3v1h-3v-2h3v1zm-14 0h3v1H4v-2h3v1z"/>
        <circle cx="12" cy="12" r="2"/>
        <rect x="11.5" y="1" width="1" height="3"/>
        <rect x="11.5" y="20" width="1" height="3"/>
        <rect x="1" y="11.5" width="3" height="1"/>
        <rect x="20" y="11.5" width="3" height="1"/>
      </svg>
      `);
      img.alt = 'Recenter';
      img.style.width = '30px';
      img.style.height = '30px';
      img.style.cursor = 'pointer';
      img.onclick = handleClick;
      return img;
    };
    control.addTo(map);
    return () => {
      control.remove();
    };
  }, [map, position]);

  return null;
};

export default function Map() {
  const [position, setPosition] = useState([48.8566, 2.3522]); // Default position (Paris)
  const maxZoom = 18; // Maximum zoom level

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const { latitude, longitude } = pos.coords;
          setPosition([latitude, longitude]);
        },
        (err) => {
          console.error('Error getting position:', err);
        }
      );
    }
  }, []);

  return (
    <div style={{ position: 'relative', height: '100%', width: '100%' }}>
      <MapContainer 
        center={position} 
        zoom={maxZoom} 
        style={{ height: '100%', width: '100%', filter: 'invert(90%) hue-rotate(180deg)' }} // Apply dark filter
        zoomControl={false}
      >
        <TileLayer
          url="https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, <a href="https://cyclosm.org/">CyclOSM</a>'
        />
        <ZoomControl position="topright" />
        <Marker position={position} icon={userIcon}>
          <Popup>You are here</Popup>
        </Marker>
        <CenterMap position={position} />
        <RecenterControl position={position} />
      </MapContainer>
    </div>
  );
}