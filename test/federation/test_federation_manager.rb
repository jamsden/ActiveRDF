# Author:: Eyal Oren
# Copyright:: (c) 2005-2006
# License:: LGPL

require 'test/unit'
require 'active_rdf'
require 'federation/federation_manager'
require "#{File.dirname(__FILE__)}/../common"

class TestFederationManager < Test::Unit::TestCase
  def setup
    ConnectionPool.clear
  end

  def teardown
  end

  @@eyal = RDFS::Resource.new("http://activerdf.org/test/eyal")
  @@age = RDFS::Resource.new("http://activerdf.org/test/age")
  @@age_number = RDFS::Resource.new("27")
  @@eye = RDFS::Resource.new("http://activerdf.org/test/eye")
  @@eye_value = RDFS::Resource.new("blue")
  @@type = RDFS::Resource.new("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
  @@person = RDFS::Resource.new("http://www.w3.org/2000/01/rdf-schema#Resource")
  @@resource = RDFS::Resource.new("http://activerdf.org/test/Person")


  def test_single_pool
    a1 = get_adapter
    a2 = get_adapter
    assert_equal a1, a2
    assert_equal a1.object_id, a2.object_id
  end

  def test_class_add
    write1 = get_write_adapter
    FederationManager.add(@@eyal, @@age, @@age_number)

    age_result = Query.new.select(:o).where(@@eyal, @@age, :o).execute
    assert "27", age_result
  end

  def test_class_add_no_write_adapter
    # zero write, one read -> must raise error

    adapter = get_read_only_adapter
    assert(!(adapter.writes?))
    assert_raises NoMethodError do
      FederationManager.add(@@eyal, @@age, @@age_number)
    end
  end

  def test_class_add_one_write_one_read
    # one write, one read

    write1 = get_write_adapter
    read1 = get_read_only_adapter
    assert_not_equal write1,read1
    assert_not_equal write1.object_id, read1.object_id

    FederationManager.add(@@eyal, @@age, @@age_number)

    age_result = Query.new.select(:o).where(@@eyal, @@age, :o).execute
    assert "27", age_result
  end

  def test_get_different_read_and_write_adapters
    r1 = get_adapter
    r2 = get_different_adapter(r1)
    assert_not_equal r1,r2
    assert_not_equal r1.object_id, r2.object_id

    w1 = get_write_adapter
    w2 = get_different_write_adapter(w1)
    assert_not_equal w1,w2
    assert_not_equal w1.object_id, w2.object_id
  end

  def test_class_add_two_write
    # two write, one read, no switching
    # we need to different write adapters for this
    #

    write1 = get_write_adapter
    write2 = get_different_write_adapter(write1)

    read1 = get_read_only_adapter

    FederationManager.add(@@eyal, @@age, @@age_number)

    age_result = Query.new.select(:o).where(@@eyal, @@age, :o).execute
    assert "27", age_result
  end

  def test_class_add_two_write_switching
    # two write, one read, with switching

    write1 = get_write_adapter
    write2 = get_different_write_adapter(write1)

    read1 = get_read_only_adapter

    FederationManager.add(@@eyal, @@age, @@age_number)
    age_result = Query.new.select(:o).where(@@eyal, @@age, :o).execute
    assert "27", age_result

    ConnectionPool.write_adapter = write2

    FederationManager.add(@@eyal, @@eye, @@eye_value)
    age_result = Query.new.select(:o).where(@@eyal, @@eye, :o).execute
    assert "blue", age_result

    second_result = write2.query(Query.new.select(:o).where(@@eyal, @@eye, :o))
    assert "blue", second_result
  end

  def test_federated_query
		unless ConnectionPool.adapter_types.include?(:sparql)
			raise(ActiveRdfError, "cannot run federation query test because sparql 
						adapter is not installed")
		end
		ConnectionPool.add_data_source(:type => :sparql, :url => 
"http://www.m3pe.org:8080/repositories/test-people", :results => :sparql_xml)

		# we first ask one sparl endpoint
    first_size = Query.new.select(:o).where(:s, :p, :o).execute(:flatten => false).size
    ConnectionPool.clear

    # then we ask the second endpoint
    ConnectionPool.add_data_source(:type => :sparql, :url =>
    "http://www.m3pe.org:8080/repositories/mindpeople", :results => :sparql_xml)

    second_size = Query.new.select(:o).where(:s, :p, :o).execute(:flatten =>
    false).size

    ConnectionPool.clear

    # now we ask both
    ConnectionPool.add_data_source(:type => :sparql, :url =>
    "http://m3pe.org:8080/repositories/test-people/", :results => :sparql_xml)
    ConnectionPool.add_data_source(:type => :sparql, :url =>
    "http://www.m3pe.org:8080/repositories/mindpeople", :results => :sparql_xml)

    union_size = Query.new.select(:o).where(:s, :p, :o).execute(:flatten => false).size
    assert_equal first_size + second_size, union_size
  end
end
