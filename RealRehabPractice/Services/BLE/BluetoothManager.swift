import Foundation
import Combine
import CoreBluetooth

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    @Published var state: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var peripherals: [DiscoveredPeripheral] = []
    @Published var lastError: String?
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var currentFlexSensorValue: Int? = nil // Current flex sensor reading (2 digits)
    
    // Computed property for connected device name
    var connectedDeviceName: String? {
        connectedPeripheral?.name
    }

    struct DiscoveredPeripheral: Identifiable, Equatable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        let rssi: Int
    }

    private var central: CBCentralManager!
    private var known: [UUID: DiscoveredPeripheral] = [:]
    private var targetPrefix: String?
    
    // BLE Service and Characteristic UUIDs
    // Common Arduino BLE UUIDs - adjust these if your Arduino uses different ones
    // If you're using HM-10 or similar, these are common defaults
    private let flexSensorServiceUUID = CBUUID(string: "FFE0") // Common service UUID
    private let flexSensorCharacteristicUUID = CBUUID(string: "FFE1") // Common characteristic UUID
    
    private var flexSensorCharacteristic: CBCharacteristic?
    private var readTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan(targetNamePrefix: String? = nil) {
        targetPrefix = targetNamePrefix
        guard central.state == .poweredOn else {
            lastError = "Bluetooth not powered on"
            print("❌ BluetoothManager: Cannot start scan - Bluetooth not powered on")
            return
        }

        known.removeAll()
        peripherals.removeAll()
        
        let prefix = targetNamePrefix ?? "all devices"
        print("🔍 BluetoothManager: Starting scan for devices with prefix '\(prefix)'")

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        print("🛑 BluetoothManager: Stopped scanning")
    }

    func connect(_ dp: DiscoveredPeripheral) {
        print("🔵 BluetoothManager: Attempting to connect to '\(dp.name)' (UUID: \(dp.id))")
        central.connect(dp.peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else {
            print("⚠️ BluetoothManager: No device connected to disconnect")
            return
        }
        print("🔵 BluetoothManager: Disconnecting from '\(peripheral.name ?? "Unknown Device")'")
        central.cancelPeripheralConnection(peripheral)
        // The didDisconnectPeripheral delegate method will handle cleanup
    }
}

extension BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        let stateString: String
        switch central.state {
        case .unknown: stateString = "Unknown"
        case .resetting: stateString = "Resetting"
        case .unsupported: stateString = "Unsupported"
        case .unauthorized: stateString = "Unauthorized"
        case .poweredOff: stateString = "Powered Off"
        case .poweredOn: stateString = "Powered On"
        @unknown default: stateString = "Unknown"
        }
        print("📡 BluetoothManager: State changed to \(stateString)")
        if central.state != .poweredOn {
            isScanning = false
            if connectedPeripheral != nil {
                connectedPeripheral = nil
                print("📱 Bluetooth Status: NOT connected to RealRehab device (Bluetooth powered off)")
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Unknown"

        if let prefix = targetPrefix,
           name.lowercased().hasPrefix(prefix.lowercased()) == false {
            return
        }

        let dp = DiscoveredPeripheral(
            id: peripheral.identifier,
            name: name,
            peripheral: peripheral,
            rssi: RSSI.intValue
        )

        if known[dp.id] == nil {
            known[dp.id] = dp
            peripherals = Array(known.values)
            print("📡 BluetoothManager: Discovered device '\(dp.name)' (RSSI: \(dp.rssi), UUID: \(dp.id))")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        connectedPeripheral = peripheral
        let deviceName = peripheral.name ?? "Unknown Device"
        print("✅ BluetoothManager: CONNECTED to '\(deviceName)' (UUID: \(peripheral.identifier))")
        print("📱 Bluetooth Status: Connected to RealRehab device")
        
        // Discover services after connection
        print("🔍 BluetoothManager: Discovering services...")
        peripheral.discoverServices(nil) // Discover all services to find the flex sensor service
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectedPeripheral = nil
        let deviceName = peripheral.name ?? "Unknown Device"
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        print("❌ BluetoothManager: FAILED to connect to '\(deviceName)' (UUID: \(peripheral.identifier))")
        print("❌ Error: \(errorMsg)")
        print("📱 Bluetooth Status: NOT connected to RealRehab device")
        lastError = error?.localizedDescription
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            let deviceName = peripheral.name ?? "Unknown Device"
            print("⚠️ BluetoothManager: DISCONNECTED from '\(deviceName)' (UUID: \(peripheral.identifier))")
            print("📱 Bluetooth Status: NOT connected to RealRehab device")
            stopReadingFlexSensor()
        }
        if let error {
            print("❌ Disconnect error: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - Peripheral Delegate Methods for Service/Characteristic Discovery
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            print("❌ BluetoothManager: Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("⚠️ BluetoothManager: No services found")
            return
        }
        
        print("✅ BluetoothManager: Discovered \(services.count) service(s)")
        
        for service in services {
            print("📡 BluetoothManager: Service UUID: \(service.uuid)")
            // Discover characteristics for all services (we'll find the flex sensor one)
            print("🔍 BluetoothManager: Discovering characteristics for service \(service.uuid)...")
            peripheral.discoverCharacteristics(nil, for: service) // Discover all characteristics
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            print("❌ BluetoothManager: Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("⚠️ BluetoothManager: No characteristics found for service \(service.uuid)")
            return
        }
        
        print("✅ BluetoothManager: Discovered \(characteristics.count) characteristic(s) for service \(service.uuid)")
        
        // Only use the first suitable characteristic to avoid conflicts
        // Look for characteristics that support notify (preferred) or read
        for characteristic in characteristics {
            print("📡 BluetoothManager: Characteristic UUID: \(characteristic.uuid)")
            print("   Properties: \(characteristic.properties.rawValue)")
            
            // If we haven't found a characteristic yet, use this one if it supports data
            if flexSensorCharacteristic == nil {
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.read) {
                    flexSensorCharacteristic = characteristic
                    
                    // Try to subscribe to notifications first (preferred for continuous data)
                    if characteristic.properties.contains(.notify) {
                        print("🔔 BluetoothManager: Subscribing to notifications for flex sensor data...")
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if characteristic.properties.contains(.read) {
                        print("📖 BluetoothManager: Characteristic supports read, starting periodic reads...")
                        startReadingFlexSensor(peripheral: peripheral, characteristic: characteristic)
                    }
                    break // Use only the first suitable characteristic
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("❌ BluetoothManager: Error reading characteristic value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("⚠️ BluetoothManager: No data received")
            return
        }
        
        // Parse flex sensor data (expecting 2-digit number)
        if let flexValue = parseFlexSensorData(data) {
            currentFlexSensorValue = flexValue
            print("📊 BluetoothManager: Flex sensor value read: \(flexValue)")
        } else {
            print("⚠️ BluetoothManager: Failed to parse flex sensor data. Raw data: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("❌ BluetoothManager: Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("✅ BluetoothManager: Successfully subscribed to notifications for flex sensor")
        } else {
            print("⚠️ BluetoothManager: Notifications disabled for characteristic")
        }
    }
    
    // MARK: - Flex Sensor Data Reading
    
    private func parseFlexSensorData(_ data: Data) -> Int? {
        // Try parsing as UTF-8 string first (common for Arduino Serial.println)
        if let string = String(data: data, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(trimmed) {
                return value
            }
        }
        
        // Try parsing as single byte (if Arduino sends raw byte value)
        if data.count == 1 {
            return Int(data[0])
        }
        
        // Try parsing as 2-byte integer (little-endian)
        if data.count >= 2 {
            let value = Int(data[0]) | (Int(data[1]) << 8)
            return value
        }
        
        return nil
    }
    
    private func startReadingFlexSensor(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        readTimer?.invalidate()
        readTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, 
                  let peripheral = self.connectedPeripheral,
                  peripheral.state == .connected else {
                self?.readTimer?.invalidate()
                return
            }
            peripheral.readValue(for: characteristic)
        }
    }
    
    private func stopReadingFlexSensor() {
        readTimer?.invalidate()
        readTimer = nil
        flexSensorCharacteristic = nil
        currentFlexSensorValue = nil
    }
}
