#pragma once
#include "telemetry_protocol.h"
void beginBle();
uint8_t nextCommand();
bool streamingLink();
bool sendMotion(const protocol::Raw &raw,
                const protocol::Orientation &orientation);
void sendStatus(const protocol::StatusPacket &status);
