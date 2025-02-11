/* ******************************************************************************
 *
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 *  See the NOTICE file distributed with this work for additional
 *  information regarding copyright ownership.
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

//
// Created by raver119 on 16/11/17.
//
#include <graph/FlowPath.h>

namespace sd {
namespace graph {

void FlowPath::ensureNode(int nodeId) {
  if (_states.count(nodeId) == 0) {
    NodeState state(nodeId);
    _states[nodeId] = state;
  }
}

void FlowPath::ensureFrame(int frameId) {
  if (_frames.count(frameId) == 0) {
    FrameState state(frameId);
    _frames[frameId] = state;
  }
}

void FlowPath::setInnerTime(int nodeId, LongType time) {
  ensureNode(nodeId);

  _states[nodeId].setInnerTime(time);
}

void FlowPath::setOuterTime(int nodeId, LongType time) {
  ensureNode(nodeId);

  _states[nodeId].setOuterTime(time);
}

LongType FlowPath::innerTime(int nodeId) {
  ensureNode(nodeId);

  return _states[nodeId].innerTime();
}

LongType FlowPath::outerTime(int nodeId) {
  ensureNode(nodeId);

  return _states[nodeId].outerTime();
}

bool FlowPath::isNodeActive(int nodeId) {
  ensureNode(nodeId);

  return _states[nodeId].isActive();
}

void FlowPath::markNodeActive(int nodeId, bool isActive) {
  ensureNode(nodeId);

  _states[nodeId].markActive(isActive);
}

int FlowPath::branch(int nodeId) {
  ensureNode(nodeId);

  return _states[nodeId].branch();
}

void FlowPath::markBranch(int nodeId, int index) {
  ensureNode(nodeId);

  _states[nodeId].markBranch(index);
}

bool FlowPath::isFrameActive(LongType frameId) {
  ensureFrame(frameId);

  return _frames[frameId].wasActivated();
}

void FlowPath::markFrameActive(LongType frameId, bool isActive) {
  ensureFrame(frameId);

  _frames[frameId].markActivated(isActive);
}

bool FlowPath::isRewindPlanned(LongType frameId) { return _frames[frameId].isRewindPlanned(); }

void FlowPath::planRewind(LongType frameId, bool reallyRewind) { _frames[frameId].planRewind(reallyRewind); }

int FlowPath::getRewindPosition(LongType frameId) { return _frames[frameId].getRewindPosition(); }

void FlowPath::setRewindPosition(LongType frameId, int position) { _frames[frameId].setRewindPosition(position); }

void FlowPath::setRewindPositionOnce(LongType frameId, int position) {
  _frames[frameId].setRewindPositionOnce(position);
}

void FlowPath::registerFrame(LongType frameId) {
  if (_frames.count(frameId) == 0) ensureFrame(frameId);
}

void FlowPath::forgetFrame(LongType frameId) {
  if (_frames.count(frameId) > 0) _frames.erase(frameId);
}

void FlowPath::incrementNumberOfCycles(LongType frameId) { _frames[frameId].incrementNumberOfCycles(); }

LongType FlowPath::getNumberOfCycles(LongType frameId) { return _frames[frameId].getNumberOfCycles(); }

bool FlowPath::wasExecuted(int nodeId) { return _states[nodeId].wasExecuted(); }

void FlowPath::markExecuted(int nodeId, bool wasExecuted) { _states[nodeId].markExecuted(wasExecuted); }

GraphProfile* FlowPath::profile() { return &_profile; }
}  // namespace graph
}  // namespace sd
