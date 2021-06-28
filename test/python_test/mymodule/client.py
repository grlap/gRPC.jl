import grpc

import random

from grpc._cython.cygrpc import CompressionAlgorithm, CompressionLevel

import proto.route_guide_pb2_grpc as route_guide_pb2_grpc
import proto.route_guide_pb2 as route_guide_pb2

import threading
from multiprocessing import Process


def make_route_note(message, latitude, longitude):
    return route_guide_pb2.RouteNote(
        message=message,
        location=route_guide_pb2.Point(latitude=latitude, longitude=longitude))


def guide_get_one_feature(stub, point):
    feature = stub.GetFeature(point, compression=grpc.Compression.Deflate)
    print(feature)
    if not feature.location:
        print("Server returned incomplete feature")
        return

    if feature.name:
        print("Feature called %s at %s" % (feature.name, feature.location))
    else:
        print("Found no feature at %s" % feature.location)


def guide_get_feature(stub):
    guide_get_one_feature(stub, route_guide_pb2.Point(latitude=1, longitude=2))

    # guide_get_one_feature(stub, route_guide_pb2.Point(latitude=0, longitude=0))


def guide_list_features(stub):
    rectangle = route_guide_pb2.Rectangle(
        lo=route_guide_pb2.Point(latitude=400000000, longitude=-750000000),
        hi=route_guide_pb2.Point(latitude=420000000, longitude=-730000000))
    print("Looking for features between 40, -75 and 42, -73")

    features = stub.ListFeatures(rectangle)

    for feature in features:
        print("Feature called %s at %s" % (feature.name, feature.location))


def generate_route(feature_list):
    for _ in range(0, 10):
        random_feature = feature_list[random.randint(0, len(feature_list) - 1)]
        print("Visiting point %s" % random_feature.location)
        yield random_feature.location


def guide_record_route(stub):
    print("guide_record_route")
    # feature_list = route_guide_resources.read_route_guide_database()
    # route_iterator = generate_route(feature_list)
    # route_summary = stub.RecordRoute(route_iterator)
    # print("Finished trip with %s points " % route_summary.point_count)
    # print("Passed %s features " % route_summary.feature_count)
    # print("Travelled %s meters " % route_summary.distance)
    # print("It took %s seconds " % route_summary.elapsed_time)


def generate_messages():
    messages = [
        make_route_note("First message", 0, 0),
        make_route_note("Second message", 0, 1),
        make_route_note("Third message", 1, 0),
        make_route_note("Fourth message", 0, 0),
        make_route_note("Fifth message", 1, 0),
    ]
    for msg in messages:
        print("Sending %s at %s" % (msg.message, msg.location))
        yield msg


def guide_route_chat(stub):
    responses = stub.RouteChat(generate_messages())
    for response in responses:
        print("Received message %s at %s" %
              (response.message, response.location))


def run():
    # NOTE(gRPC Python Team): .close() is possible on a channel and should be
    # used in circumstances in which the with statement does not fit the needs
    # of the code.
    channel_options = [('grpc.default_compression_algorithm', CompressionAlgorithm.gzip),
                       ('grpc.grpc.default_compression_level', CompressionLevel.high)]

    with grpc.insecure_channel('localhost:50200', compression=CompressionAlgorithm.gzip) as channel:
        stub = route_guide_pb2_grpc.RouteGuideStub(channel)

        messages = make_route_note(
            "First messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst messageFirst message",
            0, 0)
        res = stub.RouteEcho(messages)

        print("-------------- GetFeature --------------")
        # guide_get_feature(stub)
        # print("-------------- ListFeatures --------------")
        # guide_list_features(stub)
        # print("-------------- RecordRoute --------------")
        # guide_record_route(stub)
        # print("-------------- RouteChat --------------")
        # guide_route_chat(stub)


def run_p():
    p = Process(target=run)
    p.start()
    return p


if __name__ == '__main__':
    run()
    print("Goodbye, World!")
