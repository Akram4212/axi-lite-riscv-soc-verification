# ============================================================
# AXI-Lite Functional Coverage Tracker
#
# Lightweight Python coverage model for cocotb tests.
# Tracks address regions, access types, responses, WSTRB values,
# error cases, and subsystem peripheral access.
# ============================================================

AXI_OKAY = 0
AXI_SLVERR = 2

RAM_BASE = 0x0000_0000
RAM_END = 0x0000_0FFF

GPIO_BASE = 0x1000_0000
GPIO_END = 0x1000_0FFF

TIMER_BASE = 0x1000_1000
TIMER_END = 0x1000_1FFF


class AxiLiteCoverage:
    def __init__(self):
        self.address_regions = {
            "RAM": False,
            "GPIO": False,
            "TIMER": False,
            "INVALID": False,
        }

        self.access_types = {
            "READ": False,
            "WRITE": False,
        }

        self.responses = {
            "OKAY": False,
            "SLVERR": False,
            "OTHER": False,
        }

        self.wstrb_patterns = {
            0x0: False,
            0x1: False,
            0x2: False,
            0x4: False,
            0x8: False,
            0x3: False,
            0xC: False,
            0x5: False,
            0xA: False,
            0xF: False,
        }

        self.error_cases = {
            "UNALIGNED_ACCESS": False,
            "INVALID_REGION": False,
            "OUT_OF_RANGE": False,
        }

        self.peripheral_access = {
            "RAM_READ": False,
            "RAM_WRITE": False,
            "GPIO_READ": False,
            "GPIO_WRITE": False,
            "TIMER_READ": False,
            "TIMER_WRITE": False,
            "INVALID_READ": False,
            "INVALID_WRITE": False,
        }

        self.total_reads = 0
        self.total_writes = 0
        self.total_accesses = 0

    # ------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------

    def _to_int(self, value):
        """
        Convert normal ints, cocotb BinaryValue-like objects, or signal values
        into Python ints.
        """
        try:
            return int(value)
        except TypeError:
            return int(value.value)

    def classify_region(self, addr):
        addr = self._to_int(addr)

        if RAM_BASE <= addr <= RAM_END:
            return "RAM"
        if GPIO_BASE <= addr <= GPIO_END:
            return "GPIO"
        if TIMER_BASE <= addr <= TIMER_END:
            return "TIMER"
        return "INVALID"

    def classify_response(self, response):
        response = self._to_int(response)

        if response == AXI_OKAY:
            return "OKAY"
        if response == AXI_SLVERR:
            return "SLVERR"
        return "OTHER"

    def _sample_common(self, addr, access_type, response):
        addr = self._to_int(addr)
        response = self._to_int(response)

        region = self.classify_region(addr)
        resp_name = self.classify_response(response)

        self.total_accesses += 1

        self.address_regions[region] = True
        self.access_types[access_type] = True
        self.responses[resp_name] = True

        if addr % 4 != 0:
            self.error_cases["UNALIGNED_ACCESS"] = True

        if region == "INVALID":
            self.error_cases["INVALID_REGION"] = True

        if region == "INVALID" and resp_name == "SLVERR":
            self.error_cases["OUT_OF_RANGE"] = True

        key = f"{region}_{access_type}"
        if key in self.peripheral_access:
            self.peripheral_access[key] = True

    # ------------------------------------------------------------
    # Public sampling methods
    # ------------------------------------------------------------

    def sample_read(self, addr, response):
        """
        Sample one AXI-Lite read transaction.
        """
        self.total_reads += 1
        self._sample_common(addr, "READ", response)

    def sample_write(self, addr, response, strobe=0xF):
        """
        Sample one AXI-Lite write transaction.
        """
        strobe = self._to_int(strobe) & 0xF

        self.total_writes += 1
        self._sample_common(addr, "WRITE", response)

        if strobe in self.wstrb_patterns:
            self.wstrb_patterns[strobe] = True
        else:
            self.wstrb_patterns[strobe] = True

    def sample_access(self, addr, access_type, response, strobe=None):
        """
        Generic sampler.

        access_type should be:
            "READ"
            "WRITE"
        """
        access_type = access_type.upper()

        if access_type == "READ":
            self.sample_read(addr, response)
        elif access_type == "WRITE":
            if strobe is None:
                strobe = 0xF
            self.sample_write(addr, response, strobe)
        else:
            raise ValueError(f"Unsupported AXI-Lite access type: {access_type}")

    # ------------------------------------------------------------
    # Reporting
    # ------------------------------------------------------------

    def _hit_text(self, hit):
        return "HIT" if hit else "MISS"

    def _section_lines(self, title, bins):
        lines = []
        lines.append("")
        lines.append(title)
        lines.append("-" * len(title))

        for name, hit in bins.items():
            if isinstance(name, int):
                bin_name = f"0b{name:04b}"
            else:
                bin_name = str(name)

            lines.append(f"{bin_name:<24} {self._hit_text(hit)}")

        return lines

    def coverage_percent(self):
        all_bins = []

        for group in [
            self.address_regions,
            self.access_types,
            self.responses,
            self.wstrb_patterns,
            self.error_cases,
            self.peripheral_access,
        ]:
            all_bins.extend(group.values())

        if not all_bins:
            return 0.0

        hit_count = sum(1 for hit in all_bins if hit)
        return 100.0 * hit_count / len(all_bins)

    def report_lines(self):
        lines = []

        lines.append("")
        lines.append("============================================================")
        lines.append("AXI-Lite Functional Coverage Summary")
        lines.append("============================================================")
        lines.append(f"Total accesses: {self.total_accesses}")
        lines.append(f"Total reads:    {self.total_reads}")
        lines.append(f"Total writes:   {self.total_writes}")
        lines.append(f"Coverage:       {self.coverage_percent():.2f}%")

        lines.extend(self._section_lines("Address Regions", self.address_regions))
        lines.extend(self._section_lines("Access Types", self.access_types))
        lines.extend(self._section_lines("AXI Responses", self.responses))
        lines.extend(self._section_lines("WSTRB Patterns", self.wstrb_patterns))
        lines.extend(self._section_lines("Error Cases", self.error_cases))
        lines.extend(self._section_lines("Peripheral Access", self.peripheral_access))

        lines.append("")
        lines.append("============================================================")

        return lines

    def report(self, logger=None):
        """
        Print coverage summary.

        If logger is provided, use logger.info().
        Otherwise, use print().
        """
        lines = self.report_lines()

        for line in lines:
            if logger is not None:
                logger.info(line)
            else:
                print(line)

    def missing_bins(self):
        missing = {}

        groups = {
            "Address Regions": self.address_regions,
            "Access Types": self.access_types,
            "AXI Responses": self.responses,
            "WSTRB Patterns": self.wstrb_patterns,
            "Error Cases": self.error_cases,
            "Peripheral Access": self.peripheral_access,
        }

        for group_name, group in groups.items():
            missed = []

            for name, hit in group.items():
                if not hit:
                    if isinstance(name, int):
                        missed.append(f"0b{name:04b}")
                    else:
                        missed.append(str(name))

            if missed:
                missing[group_name] = missed

        return missing

    def assert_minimum_coverage(self, min_percent=80.0):
        """
        Optional check to fail the test if coverage is below a threshold.
        """
        percent = self.coverage_percent()

        assert percent >= min_percent, (
            f"Functional coverage below target: "
            f"{percent:.2f}% < {min_percent:.2f}%"
        )