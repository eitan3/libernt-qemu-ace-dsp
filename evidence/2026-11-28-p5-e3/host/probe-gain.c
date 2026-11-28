/* E3 probe, outside the tree, never committed: the gain entry as the tree declares it against the
 * pinned SOF header's own struct (src/audio/volume/peak_volume.h at fcebbbf2), sizeof and offsetof. */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* the tree's declaration, through the host stubs' types */
#include <ntddk.h>
#include "sofipc4.h"

/* the pinned header's struct, its words copied here for the probe alone (BSD-3-Clause, Intel) */
#define __packed __attribute__((packed))
#define __aligned(x) __attribute__((aligned(x)))
struct ipc4_peak_volume_config {
	uint32_t channel_id;
	uint32_t target_volume;
	uint32_t curve_type;
	uint32_t reserved;
	uint64_t curve_duration;
} __packed __aligned(4);

int main(void)
{
	printf("tree:   sizeof %zu  channel %zu target %zu curve %zu reserved %zu duration %zu\n",
	       sizeof(SOFIPC4_GAIN_CONFIG), offsetof(SOFIPC4_GAIN_CONFIG, ChannelId), offsetof(SOFIPC4_GAIN_CONFIG, TargetVolume),
	       offsetof(SOFIPC4_GAIN_CONFIG, CurveType), offsetof(SOFIPC4_GAIN_CONFIG, Reserved), offsetof(SOFIPC4_GAIN_CONFIG, CurveDuration));
	printf("sof:    sizeof %zu  channel %zu target %zu curve %zu reserved %zu duration %zu\n",
	       sizeof(struct ipc4_peak_volume_config), offsetof(struct ipc4_peak_volume_config, channel_id),
	       offsetof(struct ipc4_peak_volume_config, target_volume), offsetof(struct ipc4_peak_volume_config, curve_type),
	       offsetof(struct ipc4_peak_volume_config, reserved), offsetof(struct ipc4_peak_volume_config, curve_duration));
	/* the bytes of the entry the driver builds, little endian, on the wire */
	{
		SOFIPC4_GAIN_CONFIG e;
		unsigned char *p = (unsigned char *)&e;
		int i;
		memset(&e, 0, sizeof(e));
		e.ChannelId = SOFIPC4_GAIN_ALL_CHANNELS;
		e.TargetVolume = 0x4026e73d;
		e.CurveType = SOFIPC4_GAIN_CURVE_NONE;
		for (i = 0; i < (int)sizeof(e); i++)
			printf("%02x ", p[i]);
		printf("\n");
	}
	return sizeof(SOFIPC4_GAIN_CONFIG) == sizeof(struct ipc4_peak_volume_config) ? 0 : 1;
}
