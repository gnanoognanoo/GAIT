#include "ble_manager.h"
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <atomic>

namespace {
NimBLECharacteristic *rawCharacteristic, *orientationCharacteristic,
    *statusCharacteristic;
std::atomic<uint16_t> peer{BLE_HS_CONN_HANDLE_NONE};
std::atomic<bool> encrypted{false};
QueueHandle_t commands;
class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &info) override {
    peer = info.getConnHandle();
    encrypted = info.isEncrypted();
    xQueueReset(commands);
    server->updateConnParams(info.getConnHandle(), 12, 24, 0, 200);
    NimBLEDevice::startSecurity(info.getConnHandle());
  }
  void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int) override {
    encrypted = false;
    peer = BLE_HS_CONN_HANDLE_NONE;
    xQueueReset(commands);
    const uint8_t stop = protocol::Stop;
    xQueueSend(commands, &stop, 0);
    NimBLEDevice::startAdvertising();
  }
  void onAuthenticationComplete(NimBLEConnInfo &info) override {
    encrypted = info.isEncrypted();
  }
} serverCallbacks;
class ControlCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *characteristic,
               NimBLEConnInfo &info) override {
    const auto value = characteristic->getValue();
    if (!info.isEncrypted() || value.size() != 1 ||
        value[0] < protocol::Start || value[0] > protocol::Status)
      return;
    const uint8_t command = value[0];
    xQueueSend(commands, &command, 0);
  }
} controlCallbacks;
} // namespace
void beginBle() {
  commands = xQueueCreate(8, sizeof(uint8_t));
  NimBLEDevice::init("KINETIQ");
  NimBLEDevice::setSecurityAuth(true, false, true);
  NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);
  auto *server = NimBLEDevice::createServer();
  server->setCallbacks(&serverCallbacks);
  auto *service = server->createService(protocol::service);
  rawCharacteristic =
      service->createCharacteristic(protocol::raw, NIMBLE_PROPERTY::NOTIFY, 20);
  orientationCharacteristic = service->createCharacteristic(
      protocol::orientation, NIMBLE_PROPERTY::NOTIFY, 16);
  statusCharacteristic = service->createCharacteristic(
      protocol::status,
      NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC |
          NIMBLE_PROPERTY::NOTIFY,
      20);
  auto *control = service->createCharacteristic(
      protocol::control, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_ENC,
      1);
  control->setCallbacks(&controlCallbacks);
  server->start();
  auto *advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(protocol::service);
  advertising->enableScanResponse(true);
  advertising->setName("KINETIQ");
  advertising->start();
}
uint8_t nextCommand() {
  uint8_t command = 0;
  xQueueReceive(commands, &command, 0);
  return command;
}
bool streamingLink() { return encrypted && peer != BLE_HS_CONN_HANDLE_NONE; }
bool sendMotion(const protocol::Raw &r, const protocol::Orientation &q) {
  const uint16_t handle = peer;
  if (!streamingLink())
    return false;
  const bool sentRaw = rawCharacteristic->notify(r.data(), r.size(), handle);
  const bool sentOrientation =
      orientationCharacteristic->notify(q.data(), q.size(), handle);
  return sentRaw && sentOrientation;
}
void sendStatus(const protocol::StatusPacket &s) {
  statusCharacteristic->setValue(s.data(), s.size());
  if (streamingLink())
    statusCharacteristic->notify(s.data(), s.size(), peer);
}
