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
    @Published var currentIMUValue: Float? = nil // Current IMU reading (float, zeroed)
    
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
    // Flex sensor: uint16_t over characteristic 2A56
    // IMU: float over characteristic 2A57
    private let flexSensorCharacteristicUUID = CBUUID(string: "2A56") // Flex sensor characteristic UUID
    private let imuCharacteristicUUID = CBUUID(string: "2A57") // IMU characteristic UUID
    
    private var flexSensorCharacteristic: CBCharacteristic?
    private var imuCharacteristic: CBCharacteristic?
    private var readTimer: Timer?
    private var rawIMUValue: Float? = nil // Raw IMU value before offset
    private var imuZeroOffset: Float = 0.0 // Offset to zero IMU when lesson begins

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
    
    func zeroIMUValue() {
        // Store current raw IMU value as offset to zero it out
        if let rawValue = rawIMUValue {
            imuZeroOffset = rawValue
            // Update current IMU value to be zero (or close to zero)
            currentIMUValue = rawValue - imuZeroOffset
            print("📊 BluetoothManager: Zeroing IMU value. Raw value: \(rawValue), offset set to: \(imuZeroOffset), zeroed value: \(currentIMUValue ?? 0)")
        } else {
            imuZeroOffset = 0.0
            currentIMUValue = 0.0
            print("📊 BluetoothManager: Zeroing IMU value. No current value, offset set to 0")
        }
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
        
        // Look for both flex sensor and IMU characteristics
        for characteristic in characteristics {
            print("📡 BluetoothManager: Characteristic UUID: \(characteristic.uuid)")
            print("   Properties: \(characteristic.properties.rawValue)")
            
            // Check if this is the flex sensor characteristic (2A56)
            if characteristic.uuid == flexSensorCharacteristicUUID && flexSensorCharacteristic == nil {
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
                }
            }
            
            // Check if this is the IMU characteristic (2A57)
            if characteristic.uuid == imuCharacteristicUUID && imuCharacteristic == nil {
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.read) {
                    imuCharacteristic = characteristic
                    
                    // Try to subscribe to notifications first (preferred for continuous data)
                    if characteristic.properties.contains(.notify) {
                        print("🔔 BluetoothManager: Subscribing to notifications for IMU data...")
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if characteristic.properties.contains(.read) {
                        print("📖 BluetoothManager: IMU characteristic supports read, starting periodic reads...")
                        startReadingIMU(peripheral: peripheral, characteristic: characteristic)
                    }
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
        
        // Check if this is the flex sensor characteristic
        if characteristic.uuid == flexSensorCharacteristicUUID {
            // Parse flex sensor data (expecting 2-digit number)
            if let flexValue = parseFlexSensorData(data) {
                currentFlexSensorValue = flexValue
                print("📊 BluetoothManager: Flex sensor value read: \(flexValue)")
            } else {
                print("⚠️ BluetoothManager: Failed to parse flex sensor data. Raw data: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
        }
        // Check if this is the IMU characteristic
        else if characteristic.uuid == imuCharacteristicUUID {
            // Parse IMU data (expecting float)
            if let imuValue = parseIMUData(data) {
                // Store raw value
                rawIMUValue = imuValue
                // Apply zero offset
                currentIMUValue = imuValue - imuZeroOffset
                print("📊 BluetoothManager: IMU value read: \(imuValue), zeroed: \(currentIMUValue ?? 0)")
            } else {
                print("⚠️ BluetoothManager: Failed to parse IMU data. Raw data: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("❌ BluetoothManager: Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            if characteristic.uuid == flexSensorCharacteristicUUID {
                print("✅ BluetoothManager: Successfully subscribed to notifications for flex sensor")
            } else if characteristic.uuid == imuCharacteristicUUID {
                print("✅ BluetoothManager: Successfully subscribed to notifications for IMU")
            }
        } else {
            print("⚠️ BluetoothManager: Notifications disabled for characteristic")
        }
    }
    
    // MARK: - Flex Sensor Data Reading
    
    private func parseFlexSensorData(_ data: Data) -> Int? {
        // Flex sensor sends uint16_t (2 bytes, little-endian)
        // Prioritize 2-byte parsing since that's the expected format
        if data.count >= 2 {
            // Parse as little-endian uint16_t
            let value = Int(data[0]) | (Int(data[1]) << 8)
            return value
        }
        
        // Fallback: Try parsing as single byte
        if data.count == 1 {
            return Int(data[0])
        }
        
        // Fallback: Try parsing as UTF-8 string (for debugging)
        if let string = String(data: data, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(trimmed) {
                return value
            }
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
        imuCharacteristic = nil
        currentIMUValue = nil
        rawIMUValue = nil
        imuZeroOffset = 0.0
    }
    
    // MARK: - IMU Data Reading
    
    private func parseIMUData(_ data: Data) -> Float? {
        // IMU sends float (4 bytes)
        guard data.count >= 4 else {
            print("⚠️ BluetoothManager: IMU data too short: \(data.count) bytes")
            return nil
        }
        
        // Try parsing as little-endian float (common for Arduino)
        var floatValue: Float = 0.0
        let littleEndianData = Data(data.prefix(4))
        _ = withUnsafeMutableBytes(of: &floatValue) { buffer in
            littleEndianData.copyBytes(to: buffer)
        }
        
        // Check if value is valid (not NaN or infinite)
        if floatValue.isNaN || floatValue.isInfinite {
            // Try big-endian instead
            let bigEndianData = Data(littleEndianData.reversed())
            _ = withUnsafeMutableBytes(of: &floatValue) { buffer in
                bigEndianData.copyBytes(to: buffer)
            }
        }
        
        // Validate the float value
        if floatValue.isNaN || floatValue.isInfinite {
            print("⚠️ BluetoothManager: Invalid IMU float value (NaN or Infinite)")
            return nil
        }
        
        return floatValue
    }
    
    private func startReadingIMU(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // Start periodic reads if notifications aren't available
        // Note: This may conflict with the flex sensor timer, so we'll use notifications primarily
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
}
