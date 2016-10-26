require 'spec_helper'
require 'lackeys'
require 'active_model'

describe Lackeys::RailsBase, type: :class do
  let(:test_class) do
    Class.new do
      extend ActiveModel::Callbacks
      include Lackeys::RailsBase
    end
  end
  let(:test_class_instance) { test_class.new }
  let(:registry) { double("Registry Double") }
  before(:each) do |example|
    unless RSpec.current_example.metadata[:skip_registry_stub]
      allow(Lackeys::Registry).to receive(:new).once.and_return registry
    end
  end

  describe "should automatically generate callbacks" do
    let(:test_class_instance) { TestRailsClass.new }
    let(:before_save_called) { false }
    let(:after_save_called) { false }
    let(:before_create_called) { false }
    let(:after_create_called) { false }
    class TestRailsClass
      extend ActiveModel::Callbacks
      include Lackeys::RailsBase
    end
    class TestServiceClass < Lackeys::ServiceBase
      Lackeys::Registry.register(TestServiceClass, TestRailsClass) do |r|
        # Do nothing
        r.add_method :called
        r.add_callback :before_save, "before_save"
        r.add_callback :after_save, "after_save"
        r.add_callback :before_create, "before_create"
        r.add_callback :after_create, "after_create"
      end

      def initialize_internals; @called = []; end
      def called; @called; end

      def before_save; @called << "before_save"; end
      def after_save; @called << "after_save"; end
      def before_create; @called << "before_create"; end
      def after_create; @called << "after_create"; end
    end
    subject { test_class_instance.called }

    context "save callbacks" do
      before(:each) { test_class_instance.run_callbacks(:save) }
      it "save callbacks", skip_registry_stub: true do
        should include "before_save"
        should include "after_save"
        should_not include "before_create"
        should_not include "after_create"
      end
    end

    context "create callbacks" do
      before(:each) { test_class_instance.run_callbacks(:create) }
      it "create callback", skip_registry_stub: true do
        should_not include "before_save"
        should_not include "after_save"
        should include "before_create"
        should include "after_create"
      end
    end
  end

  describe "#registry" do
    it "should return the same registry instance every time" do
      expect(test_class_instance.registry).to be registry
      expect(test_class_instance.registry).to be registry
    end
  end

  describe "#respond_to?" do
    let(:method_name) { :test_method }

    context "registry knows the method" do
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return true
      end

      it { expect(test_class_instance.respond_to?(method_name, double())).to eq true }
    end

    context "registry does not know the method but instance knows the method" do
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
        def test_class_instance.test_method; end;
      end

      it { expect(test_class_instance.respond_to?(method_name, double())).to be true }
    end

    context "both instance and registry do not know the method" do
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
      end

      it { expect(test_class_instance.respond_to?(method_name, double())).to be false }
    end
  end

  describe "method_missing" do
    let(:method_name) { :test_method }

    context "registry knows the method" do
      let(:return_value) { "100" }
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return true
        expect(registry).to receive(:call).with(method_name).and_return return_value
      end

      it { expect(test_class_instance.send(method_name)).to eq return_value }
    end

    context "registry does not know the method" do
      let(:alternate_return_value) { "200" }
      let(:test_class_instance) { DummyClass.new }
      class ParentDummyClass
        def method_missing(method_name, *args, &block); "200"; end
      end
      class DummyClass < ParentDummyClass
        extend ActiveModel::Callbacks
        include Lackeys::RailsBase
      end;
      before(:each) do
        expect(registry).to receive(:method?).with(method_name).and_return false
      end

      it { expect(test_class_instance.send(method_name)).to eq alternate_return_value }
    end
  end
end