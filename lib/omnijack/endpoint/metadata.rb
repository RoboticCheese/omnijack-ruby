# Encoding: UTF-8
#
# Author:: Jonathan Hartman (<j@p4nt5.com>)
#
# Copyright (C) 2014-2015 Jonathan Hartman
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'open-uri'
require_relative '../config'
require_relative '../endpoint'

class Omnijack
  class Endpoint < Omnijack
    # A class for representing an Omnitruck metadata object
    #
    # @author Jonathan Hartman <j@p4nt5.com>
    class Metadata < Endpoint
      include ::Chef::Mixin::ParamsValidate
      include Config

      def initialize(name, args)
        super
        [:platform, :platform_version, :machine_arch].each do |i|
          send(i, args[i])
          args.delete(i)
        end
        args.each { |k, v| send(k, v) unless v.nil? } unless args.nil?
        version(to_h[:version])
        to_h
      end

      #
      # Set up an accessor method for each piece of metadata
      #
      METADATA_ATTRIBUTES.concat([:filename, :build]).each do |a|
        define_method(a) { to_h[a] }
      end

      #
      # Offer a hash representation of the metadata
      #
      # @return [Hash]
      #
      def to_h
        raw_data.split("\n").each_with_object({}) do |line, hsh|
          key, val = line.split.entries
          key = key.to_sym
          val = true if val == 'true'
          val = false if val == 'false'
          hsh[key] = val
          key == :url && hsh.merge!(parse_url_data(val))
        end
      end

      #
      # The version of the project
      #
      # @param [String, NilClass] arg
      # @return [String]
      #
      def version(arg = nil)
        set_or_return(:version, arg, kind_of: String, default: 'latest')
      end

      #
      # Whether to enable prerelease and/or nightly packages
      #
      # @param [TrueClass, FalseClass, NilClass] arg
      # @return [TrueClass, FalseClass]
      #
      [:prerelease, :nightlies].each do |m|
        define_method(m) do |arg = nil|
          set_or_return(m,
                        arg,
                        kind_of: [TrueClass, FalseClass],
                        default: false)
        end
      end

      #
      # The name of the desired platform
      #
      # @param [String, NilClass]
      # @return [String]
      #
      def platform(arg = nil)
        set_or_return(:platform, arg, kind_of: String, required: true)
      end

      #
      # The version of the desired platform
      #
      # @param [String, NilClass] arg
      # @return [String]
      #
      def platform_version(arg = nil)
        !arg.nil? && arg = case platform
                           when 'mac_os_x' then platform_version_mac_os_x(arg)
                           when 'windows' then platform_version_windows(arg)
                           else arg
                           end
        set_or_return(:platform_version, arg, kind_of: String, required: true)
      end

      #
      # The machine architecture of the desired platform
      #
      # @param [String, NilClass]
      # @return [String]
      #
      def machine_arch(arg = nil)
        set_or_return(:machine_arch, arg, kind_of: String, required: true)
      end

      private

      #
      # Construct the full API query URL from base + endpoint + params
      #
      # @return [URI::HTTP, URI::HTTPS]
      #
      def api_url
        @api_url ||= URI.parse("#{super}?#{URI.encode_www_form(query_params)}")
      end

      #
      # Convert all the metadata attrs into params Omnitruck understands
      #
      # @return [Hash]
      #
      def query_params
        { v: version, prerelease: prerelease, nightlies: nightlies,
          p: platform, pv: platform_version, m: machine_arch }
      end

      #
      # Apply special logic for the version of an OS X platform
      #
      # @param [String] arg
      # @return [String]
      #
      def platform_version_mac_os_x(arg)
        arg.match(/^[0-9]+\.[0-9]+/).to_s
      end

      #
      # Apply special logic for the version of a Windows platform
      #
      # @param [String] arg
      # @return [String]
      #
      def platform_version_windows(arg)
        # Make a best guess and assume a server OS
        # See: http://msdn.microsoft.com/en-us/library/windows/
        #      desktop/ms724832(v=vs.85).aspx
        {
          '6.3' => '2012r2', '6.2' => '2012', '6.1' => '2008r2',
          '6.0' => '2008', '5.2' => '2003r2', '5.1' => 'xp', '5.0' => '2000'
        }[arg.match(/^[0-9]+\.[0-9]+/).to_s]
      end

      #
      # Extract a filename, package version, and build from a package URL
      #
      # @param [String] url
      # @return [[String] filename, [String] version, [String] build]
      #
      def parse_url_data(url)
        filename = URI.decode(url).split('/')[-1]
        { filename: filename,
          version: filename.split('-')[-2].split('_')[-1],
          build: filename.split('-')[-1].split('.')[0].split('_')[0] }
      end
    end
  end
end
