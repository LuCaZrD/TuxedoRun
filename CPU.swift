import Cocoa

// MARK: - CPU

final class CPUMeter {
    private var last: [UInt32] = []
    func usage() -> Double {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return 0 }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)) }
        var now: [UInt32] = []
        for i in 0..<Int(count) {
            for s in 0..<Int(CPU_STATE_MAX) { now.append(UInt32(bitPattern: info[i * Int(CPU_STATE_MAX) + s])) }
        }
        defer { last = now }
        guard last.count == now.count else { return 0 }
        var busy = 0.0, total = 0.0
        for i in 0..<Int(count) {
            let base = i * Int(CPU_STATE_MAX)
            let user = Double(now[base + Int(CPU_STATE_USER)] &- last[base + Int(CPU_STATE_USER)])
            let sys = Double(now[base + Int(CPU_STATE_SYSTEM)] &- last[base + Int(CPU_STATE_SYSTEM)])
            let nice = Double(now[base + Int(CPU_STATE_NICE)] &- last[base + Int(CPU_STATE_NICE)])
            let idle = Double(now[base + Int(CPU_STATE_IDLE)] &- last[base + Int(CPU_STATE_IDLE)])
            busy += user + sys + nice
            total += user + sys + nice + idle
        }
        return total > 0 ? busy / total * 100 : 0
    }
}
