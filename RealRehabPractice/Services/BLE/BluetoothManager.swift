import Foundation
import Combine
import CoreBluetooth

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    @Published var state: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var peripherals: [DiscoveredPeripheral] = []
    @Published var lastError: String?

    struct DiscoveredPeripheral: Identifiable, Equatable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        let rssi: Int
    }

    private var central: CBCentralManager!
    private var known: [UUID: DiscoveredPeripheral] = [:]
    private var targetPrefix: String?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan(targetNamePrefix: String? = nil) {
        targetPrefix = targetNamePrefix
        guard central.state == .poweredOn else {
            lastError = "Bluetooth not powered on"
            return
        }

        known.removeAll()
        peripherals.removeAll()

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
    }

    func connect(_ dp: DiscoveredPeripheral) {
        central.connect(dp.peripheral, options: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        if central.state != .poweredOn {
            isScanning = false
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
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        print("✅ BLE connected to \(peripheral.identifier)")
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        lastError = error?.localizedDescription
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error {
            lastError = error.localizedDescription
        }
    }
}
