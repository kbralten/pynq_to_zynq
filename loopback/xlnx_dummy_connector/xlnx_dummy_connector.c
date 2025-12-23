// SPDX-License-Identifier: GPL-2.0
/*
 * Xilinx DRM Dummy Encoder/Connector
 * 
 * Simple encoder/connector for xlnx-drm that provides fixed display modes
 * for custom video output (RGB2DVI, etc.)
 * 
 * Copyright (C) 2025
 */

#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/component.h>
#include <linux/of.h>
#include <drm/drm_atomic_helper.h>
#include <drm/drm_crtc.h>
#include <drm/drm_crtc_helper.h>
#include <drm/drm_edid.h>
#include <drm/drm_encoder.h>
#include <drm/drm_probe_helper.h>
#include <drm/drm_simple_kms_helper.h>

#define DRIVER_NAME "xlnx-dummy-connector"

struct xlnx_dummy {
	struct drm_device *drm;
	struct drm_encoder encoder;
	struct drm_connector connector;
};

static const struct drm_display_mode default_mode = {
	.clock = 74250,
	.hdisplay = 1280,
	.hsync_start = 1280 + 110,
	.hsync_end = 1280 + 110 + 40,
	.htotal = 1280 + 110 + 40 + 220,
	.vdisplay = 720,
	.vsync_start = 720 + 5,
	.vsync_end = 720 + 5 + 5,
	.vtotal = 720 + 5 + 5 + 20,
	.type = DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED,
	.flags = DRM_MODE_FLAG_PHSYNC | DRM_MODE_FLAG_PVSYNC,
	.name = "1280x720",
};

/* Connector functions */
static int xlnx_dummy_connector_get_modes(struct drm_connector *connector)
{
	struct drm_display_mode *mode;

	mode = drm_mode_duplicate(connector->dev, &default_mode);
	if (!mode) {
		dev_err(connector->dev->dev, "Failed to create mode\n");
		return 0;
	}

	drm_mode_probed_add(connector, mode);
	return 1;
}

static enum drm_mode_status
xlnx_dummy_connector_mode_valid(struct drm_connector *connector,
				struct drm_display_mode *mode)
{
	/* Accept 720p60 only */
	if (mode->hdisplay == 1280 && mode->vdisplay == 720)
		return MODE_OK;
	
	return MODE_BAD;
}

static const struct drm_connector_helper_funcs xlnx_dummy_connector_helper_funcs = {
	.get_modes = xlnx_dummy_connector_get_modes,
	.mode_valid = xlnx_dummy_connector_mode_valid,
};

static enum drm_connector_status
xlnx_dummy_connector_detect(struct drm_connector *connector, bool force)
{
	/* Always report connected */
	return connector_status_connected;
}

static const struct drm_connector_funcs xlnx_dummy_connector_funcs = {
	.detect = xlnx_dummy_connector_detect,
	.fill_modes = drm_helper_probe_single_connector_modes,
	.destroy = drm_connector_cleanup,
	.reset = drm_atomic_helper_connector_reset,
	.atomic_duplicate_state = drm_atomic_helper_connector_duplicate_state,
	.atomic_destroy_state = drm_atomic_helper_connector_destroy_state,
};

/* Encoder functions */
static const struct drm_encoder_funcs xlnx_dummy_encoder_funcs = {
	.destroy = drm_encoder_cleanup,
};

/* Component binding */
static int xlnx_dummy_bind(struct device *dev, struct device *master, void *data)
{
	struct xlnx_dummy *dummy = dev_get_drvdata(dev);
	struct drm_device *drm = data;
	struct drm_encoder *encoder = &dummy->encoder;
	struct drm_connector *connector = &dummy->connector;
	int ret;

	dummy->drm = drm;

	/* Initialize encoder */
	encoder->possible_crtcs = 1; /* Attach to first CRTC */
	ret = drm_simple_encoder_init(drm, encoder, DRM_MODE_ENCODER_NONE);
	if (ret) {
		dev_err(dev, "Failed to initialize encoder: %d\n", ret);
		return ret;
	}

	/* Initialize connector */
	connector->polled = 0; /* No polling needed, always connected */
	ret = drm_connector_init(drm, connector, &xlnx_dummy_connector_funcs,
				 DRM_MODE_CONNECTOR_HDMIA);
	if (ret) {
		dev_err(dev, "Failed to initialize connector: %d\n", ret);
		drm_encoder_cleanup(encoder);
		return ret;
	}

	drm_connector_helper_add(connector, &xlnx_dummy_connector_helper_funcs);

	/* Attach connector to encoder */
	ret = drm_connector_attach_encoder(connector, encoder);
	if (ret) {
		dev_err(dev, "Failed to attach connector: %d\n", ret);
		drm_connector_cleanup(connector);
		drm_encoder_cleanup(encoder);
		return ret;
	}

	dev_info(dev, "Dummy encoder/connector bound successfully\n");
	return 0;
}

static void xlnx_dummy_unbind(struct device *dev, struct device *master, void *data)
{
	struct xlnx_dummy *dummy = dev_get_drvdata(dev);

	drm_connector_cleanup(&dummy->connector);
	drm_encoder_cleanup(&dummy->encoder);
}

static const struct component_ops xlnx_dummy_component_ops = {
	.bind = xlnx_dummy_bind,
	.unbind = xlnx_dummy_unbind,
};

/* Platform driver */
static int xlnx_dummy_probe(struct platform_device *pdev)
{
	struct xlnx_dummy *dummy;

	dummy = devm_kzalloc(&pdev->dev, sizeof(*dummy), GFP_KERNEL);
	if (!dummy)
		return -ENOMEM;

	platform_set_drvdata(pdev, dummy);

	return component_add(&pdev->dev, &xlnx_dummy_component_ops);
}

static void xlnx_dummy_remove(struct platform_device *pdev)
{
	component_del(&pdev->dev, &xlnx_dummy_component_ops);
}

static const struct of_device_id xlnx_dummy_of_match[] = {
	{ .compatible = "xlnx,dummy-connector" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, xlnx_dummy_of_match);

static struct platform_driver xlnx_dummy_driver = {
	.probe = xlnx_dummy_probe,
	.remove = xlnx_dummy_remove,
	.driver = {
		.name = DRIVER_NAME,
		.of_match_table = xlnx_dummy_of_match,
	},
};

module_platform_driver(xlnx_dummy_driver);

MODULE_AUTHOR("Custom");
MODULE_DESCRIPTION("Xilinx DRM Dummy Encoder/Connector");
MODULE_LICENSE("GPL");
